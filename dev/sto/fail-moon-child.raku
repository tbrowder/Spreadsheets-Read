#!/usr/bin/env raku

# Simulating a spreadsheet sheet/cell reader:

sub do-things-with-sheet($s) {
    die "overly twoish" if $s == 2;
    # ...
}

sub do-things-with-cell($s, $c) {
    die "illuminati freaks me out" if $s == $c == 3;
    # ...
}

my $ns = 3;
my $nc = 4;
SHEET: for 1..$ns -> $s {
    CATCH { default { say "WARNING: bad sheet $s ({.Str}), skipping it entirely"; next SHEET; } }
    do-things-with-sheet $s;
    say "== sheet $s";

    CELL: for 1..$nc -> $c {
	CATCH { default { say "WARNING: bad sheet $s, cell $c ({.Str})"; next CELL; } }
	do-things-with-cell $s, $c;
	say "  == cell $c";
    }
}
