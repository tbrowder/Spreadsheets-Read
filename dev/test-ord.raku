my $col = 1;
my $label = "";
my $c = chr(--$col mod 26 + ord("A"));
#$label.substr-rw: 0, 0, $c;
$label.substr-rw(0, 0) = $c;

say "col $col, label '$label', chr '$c'";

$label = "B";
$col = label2col $label;
say "label '$label', col '$col'";

#| (D) => (4)
sub label2col($label is copy where $label ~~ /^:i <[A..Z]>+$/) is export {
    $label .= uc;
    my $col = 0;
    while $label ~~ s/^(<[A..Z]>)// {
        $col = 26 * $col + 1 + ord(~$0) - ord("A");
    }
    $col
} # sub label2col

#| (4) => (D)
sub col2label(Int $col is copy where $col > 0) is export {
    my $label = "";
    while $col {
        #substr-rw $label, 0, 0, chr(-$col % 26 + ord("A"));
        $label.substr-rw(0, 0) = chr(--$col mod 26 + ord("A"));
        $col = $col div 26;
    }
    $label
} # sub col2label

