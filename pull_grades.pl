use strict;
use Net::Google::Spreadsheets;

my ($username, $password) = @ARGV;
my $service = Net::Google::Spreadsheets->new(
    username => $username,
    password => $password
);

my $spreadsheet = $service->spreadsheet(
    { title => 'Spring 2010 Gradebook' }
);

my @worksheets = $spreadsheet->worksheets;

for my $worksheet (@worksheets) {
    my ($class, $assignments, $students) = assignments_and_students_info($worksheet);

    open my $fh, '>', "$class.data" or die "Cannot open $class.data: $!";

    local $" = "\t";
    # print the # of assignments and students, then the data
    print { $fh } "@{$_}\n" for [0+@$assignments, 0+@$students], @$assignments, @$students;
    close $fh;
}

sub assignments_and_students_info {
    my ($worksheet) = @_;
    my $class = $worksheet->title eq 'Algebra 1' ? 'alg1' : $worksheet->title eq 'Algebra 2' ? 'alg2' : undef;
    my $col_start = ord('L') - ord('A') + 1;
    my $col_end = + keys %{$worksheet->row->content};
    return ( $class, assignment_info( $worksheet, $col_start, $col_end ), student_info( $worksheet, $col_end ) );
}

sub student_info {
    my ($worksheet, $end) = @_;
    my @students;
    for my $row (5..$worksheet->{'row_count'}) {
        push @students, [map { $_->content } $worksheet->cells(
            { 'return-empty' => 'true',
              'min-row' => $row,
              'max-row' => $row,
              'max-col' => $end }
        )];
        pop(@students), last if $students[-1]->[0] =~ m/^\s*$/xms;
    }
    return [@students];
}

sub assignment_info {
    my ($worksheet, $start, $end) = @_;
    my @assignments;
    for ($start..$end) {
        push @assignments, [ map { $_->content }
            $worksheet->cells(
                { 'return-empty' => 'true',
                  'min-row' => 1, 'max-row' => 4,
                  'min-col' => $_, 'max-col' => $_ }
        )];
    }
    # make sure they're integers:
    $_->[0] = 0+$_->[0] for @assignments;

    return [@assignments];
}
