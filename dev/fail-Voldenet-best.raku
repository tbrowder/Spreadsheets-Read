#!/usr/bin/env raku

# Simulating a spreadsheet sheet/cell reader:
my $ns = 3; # number of sheets
my $nc = 4; # number of cells per sheet
for 1..$ns -> $sheet-index {
    CATCH {
        default {
            say "Error in sheet $sheet-index: " ~ .Str;
        }
    }
    process-sheet($sheet-index, $nc);
}

sub process-sheet($sheet-index, $number-of-cells) {
    if $sheet-index == 2 {
        die "Some processing error";
    }

    say "== sheet $sheet-index";

    for 1..$number-of-cells -> $cell-index {
        CATCH {
            default {
                      say "Error in cell $cell-index of sheet $sheet-index: " ~ .Str;
            }
        }
        process-cell($sheet-index, $cell-index);
    }

}

sub process-cell($sheet-index, $cell-index) {
    if $sheet-index == 3 and $cell-index == 3 {
        die "Some other processing error"
    }
    say "  == sheet $sheet-index, cell $cell-index";
}
