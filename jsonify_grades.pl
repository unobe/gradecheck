#!/home/unobe/perl/5.8.9/bin/perl
# usage: $0 file1 file2 ...
# transforms into a json-encoded file, useful for directly pumping in to perl.
# it outputs them all to data.json
use strict;
use JSON;

my $json_file = 'data.json';
unlink $json_file; #delete all info before update

my $hash = {};
for my $file (@ARGV) {
    my ($assignments, $students) = extract($file);
    $hash = { %$hash, %{structure($assignments, $students)} };
}
store_json($hash, $json_file);

sub extract {
    my $file = shift;
    open my $fh, '<', $file or return;
    
    # first number is number of assignments, second is of students
    my ($number_of_assignments, $number_of_students) = split "\t", scalar <$fh>;

    my @assignments;
    for (1..$number_of_assignments) {
        # number, date, title, points
        push @assignments, [ split "\t", scalar <$fh> ];
        chomp($assignments[-1]->[-1]); # remove newline
    }

    my @students;
    for (1..$number_of_students) {
        push @students, [ split "\t", scalar <$fh> ];
        chomp($students[-1]->[-1]); # remove newline
    }

    return (\@assignments, \@students);
}

sub structure {
    my ($assignments, $students) = @_;
    # period-last5 => [ [ period, id, name, grade_level, percent, earned,
    # missed, excused, possible, teacher ], [ number, date, title, earned,
    # missed, excused, possible, total_earned, total_possible ], [ number,
    # date, title, earned, missed, excused, possible, total_earned,
    # total_possible ] ]
    my %record;
    for my $student (@$students) {
        my $key = $student->[0].'-'.substr($student->[1], -5);
        my $all_info;
        my $student_info = [@{$student}[0..9]];
        $student_info->[$_] = 0 + $student_info->[$_] for 5..8;

        # 11th element is blank
        shift @$student for 1..11;

        # XXX: Refactor to include totals for {earned,missed,excused,possible} points
        for my $assignment (@$assignments) {
            # number, date, title, earned, missed, excused, possible
            my $assignment_info = [ @{$assignment}[0..2] , 0, 0, 0, $assignment->[3] ];
            $assignment_info->[3] = shift @$student;

            # handle excused and missing assignments
            if ($assignment_info->[3] eq 'E') {
                $assignment_info->[5] = $assignment->[3];
            }
            elsif ($assignment_info->[3] =~ /^(?:A|D|R|)$/) {
                $assignment_info->[4] = $assignment->[3];
            }

            # add to assignments list
            push @$all_info, $assignment_info;
        }

        # sort ascending by number
        $all_info = [ sort { $a->[0] <=> $b->[0] } @$all_info ];
        
        # add running sum of total points earned and total points possible
        for (0..(@$all_info-1)) {
            push @{$all_info->[$_]}, 0+$all_info->[$_]->[3], 0+$all_info->[$_]->[-1];
            if ($_ != 0) {
                $all_info->[$_]->[-2] += $all_info->[$_-1]->[-2];
                $all_info->[$_]->[-1] += $all_info->[$_-1]->[-1];
            }
        }
        $record{$key} = [ $student_info, $all_info ];
    }
    return \%record;
}

sub store_json {
    my ($data, $file) = @_;
    open my $fh, '>', $file or return;
    print { $fh } encode_json $data;
    close $fh;
    return;
}