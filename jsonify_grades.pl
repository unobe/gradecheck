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
    # tack on the current class' assignment info to any data already stored:
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
    # unexcused, excused, possible, teacher ], [ number, date, title, earned,
    # possible, total_unexcused, total_excused, total_earned, total_possible ],
    # [ number, date, title, earned, possible, total_unexcused, total_excused,
    # total_earned, total_possible ] ]
    my %record;
    for my $student (@$students) {
        my $key = $student->[0].'-'.substr($student->[1], -5);
        my $all_info;
        my $student_info = [@{$student}[0..9]];
        $student_info->[$_] = 0 + $student_info->[$_] for 5..8;

        # 11th element is blank
        shift @$student for 1..11;

        my @totals = (); # running totals for: unexcused, excused, earned, and possible
        # stored in reverse-chronological order, so make sure to go through them like that for totals
        for my $assignment (reverse @$assignments) {
            # assignment_info: number, date, title, earned, possible
            my $assignment_info = [ @{$assignment}[0..2] , 0, $assignment->[3] ];
            $assignment_info->[3] = shift @$student;

            #!! assignment->[3] is the number of points assignment is worth
            # handle excused and missing assignments
            if ($assignment_info->[3] =~ /^(?:A|D|R|U|)$/) {
                $assignment_info->[5] = $total[0] += $assignment_info->[4];
            }
            elsif ($assignment_info->[3] eq 'E') {
                $assignment_info->[6] = $total[1] += $assignment_info->[4];
            }
            else { # just points
                $assignment_info->[7] = $total[2] += $assignment_info->[3];
            }
            
            # and make sure to add the points possible
            $assignment_info->[8] = $total[3] += $assignment_info->[4];

            # add to assignments list
            push @$all_info, $assignment_info;
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
