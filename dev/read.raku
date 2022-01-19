#!/usr/bin/env raku

use Text::Utils :normalize-string;

use lib <../lib>;

use Spreadsheets::Read;

my @f =
"../t/data/sample-security-sales.xlsx",
"../t/data/sample-security-sales.xls",
"../t/data/sample-security-sales.ods",
"../t/data/sample-security-sales.csv",
"../t/data/mytest.csv",
"../t/data/senior-center-schedule.xlsx",
"../t/data/tmp-sto/senior-center-schedule-orig-buggy.xlsx",
;

my $sheet = 0;
if !@*ARGS.elems {
    say qq:to/HERE/;
    Usage: {$*PROGRAM.basename} 1|2|3|4|5|6|7  [s1 s2] [debug]

    Uses the Perl module Spreadsheet::Read and
    dumps the data from the selected file number:
    HERE
    my $n = 0;
    for @f -> $f {
        ++$n;
        say "  $n. {$f.IO.basename}";
    }
    say();
    exit;
}

my $n;
my $debug = 0;
for @*ARGS {
    when /^d/ {
        $debug = 1;
    }
    when /s(1|2)/ {
        $sheet = +$0;
    }
    when /(1|2|3|4|5|6|7)/ {
        $n = +$0 - 1
    }
    default {
        say "FATAL: Unhandled arg '$_'";
        exit;
    }
}

my $ifil = @f[$n];

say "Using file '$ifil'";
my $wb = Spreadsheets::Read.new: $ifil;


fo 
if $debug {
    $c.dump;
}
say "DEBUG early exit after dump"; exit;

if $sheet > 1 and $ifil ~~ /:i csv/ {
    say "FATAL: Only one sheet in a csv file";
    exit;
}

