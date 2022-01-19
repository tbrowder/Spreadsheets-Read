use v6;
use Test;

use Spreadsheets::Read;
use Spreadsheets::Workbook;
use Spreadsheets::Classes;
use Spreadsheets::Utils;

#plan 6;

my $b;
my $file = "t/data/mytest.csv";

$b = Spreadsheets::Read.new: $file;
isa-ok $b, Spreadsheets::Read;

$b = Workbook.new: :$file;
isa-ok $b, Workbook;

$b = Sheet.new;
isa-ok $b, Sheet;

$b = Row.new;
isa-ok $b, Row;

$b = Cell.new;
isa-ok $b, Cell;

done-testing;

