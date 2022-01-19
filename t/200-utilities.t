use Test;

use Spreadsheets::Workbook;

my @col;
my @label;

@col   = 1, 2, 30;
@label = <A B AD>;

for @col.kv -> $i, $col {
    is col2label($col), @label[$i];
}

for @label.kv -> $i, $label {
    is label2col($label), @col[$i];
}


done-testing;
