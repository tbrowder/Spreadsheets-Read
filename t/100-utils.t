use Test;

use Spreadsheets::Workbook;

my @col   = 1, 2, 30;
my @label = <A B AD>;

my @colrow = <A1 B10 AD5>;
my @rowidx = 0,  9,   4;
my @colidx = 0,  1,   29;

for @col.kv -> $i, $col {
    is col2label($col), @label[$i];
}

for @label.kv -> $i, $label {
    is label2col($label), @col[$i];
}

for @colrow.kv -> $i, $colrow {
    my ($irow, $jcol) = colrow2cell $colrow;
    is $irow, @rowidx[$i];
    is $jcol, @colidx[$i];
}

for 0..2 -> $i  {
    my $irow = @rowidx[$i];
    my $jcol = @colidx[$i];
    my $colrow = cell2colrow($irow, $jcol);
    is $colrow, @colrow[$i];
}

done-testing;
