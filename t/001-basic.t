use v6;
use Test;

use Spreadsheets;
use Spreadsheets::Utils;

plan 6;

my $b;

$b = Spreadsheets.new;
isa-ok $b, Spreadsheets;

$b = WorkbookSet.new;
isa-ok $b, WorkbookSet;

$b = Workbook.new;
isa-ok $b, Workbook;

$b = Sheet.new;
isa-ok $b, Sheet;

$b = Row.new;
isa-ok $b, Row;

$b = Cell.new;
isa-ok $b, Cell;

