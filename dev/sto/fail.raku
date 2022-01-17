#!/usr/bin/env raku

# Simulating a spreadsheet sheet/cell reader:
my $ns = 3; # number of sheets
my $nc = 4; # number of cells per sheet
SHEET: for 1..$ns -> $s {
    if $s == 2 {
        # a sheet failure, recover at $s = 3
        CATCH { default { say .Str; next SHEET; } }
        die "WARNING: bad sheet $s, skipping it entirely";
    }
    say "== sheet $s";

    CELL: for 1..$nc -> $c {
        if $s == 3 and $c == 3 {
            # a cell failure, recover at $c = 4
            CATCH { default { say .Str; next CELL; } }
            die "WARNING: sheet $s, bad cell $c";
        }
        say "  == cell $c";
    }
}
