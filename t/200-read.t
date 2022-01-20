use Test;
use Spreadsheets::Read;

# defined in BEGIN block below
my @files;
my %sheets; 

plan 7;

for @files -> $file {
    lives-ok { my $wb = Spreadsheets::Read.new: $file }
}

BEGIN {

  @files = <
    t/data/mytest.csv
    t/data/sample-security-sales.ods
    t/data/sample-security-sales.xls
    t/data/sample-security-sales.xlsx
    t/data/sample-security-sales.csv
    t/data/senior-center-schedule.xlsx
    t/data/senior-center-schedule-orig-buggy.xlsx
  >;

  # from the Senior Center data
  # file: senior-center-schedule.xlsx
  %sheets = [
    # Sheet number and names:
    1 => 'Classes',
    2 => 'Descriptions',
    3 => 'special events',
    4 => 'Nov  1 2021',
    5 => 'Nov  8 2021',
    6 => 'Nov 15 2021',
    7 => 'Nov 22 2021',
    8 => 'Nov  29 2021',
    9 => 'Dec 6 2021',
    10 => 'Dec 13 2021',
    11 => 'Dec 20 2021 ',
    12 => 'Jan 3 2021',
    13 => 'Jan 10 2021 ',
  ];
}
