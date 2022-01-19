#!/usr/bin/env raku

use Text::Utils :normalize-string;

use lib <../lib>;

use Spreadsheets::Read;

my @f =
"../t/data/mytest.csv",
"../t/data/sample-security-sales.xlsx",
"../t/data/sample-security-sales.xls",
"../t/data/sample-security-sales.ods",
"../t/data/sample-security-sales.csv",
"../t/data/senior-center-schedule.xlsx",
"../t/data/tmp-sto/senior-center-schedule-orig-buggy.xlsx",
;

my $sheet = 0;
if !@*ARGS.elems {
    say qq:to/HERE/;
    Usage: {$*PROGRAM.basename} 1|2|3|4|5|6|7  [sN] [debug][Debug]

    Uses the Perl module Spreadsheet::Read and
    shows various data from the selected file.

    Selecting 'sN' selects that sheet number, if it exists.

    Selecting 'debug[=N]' will result in passing 'debug' to internals.
    Selecting 'Debug' will result in a dump and early
    exit.

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
my $Debug = 0;
my $debug = 0;
for @*ARGS {
    when /^D/ {
        $Debug = 1;
    }
    when /^'d='(\d+)/ {
        $debug = +$0;
    }
    when /^d/ {
        $debug = 1;
    }
    when /s(\d)/ {
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
my $wb = Spreadsheets::Read.new: $ifil, :$debug;
my $bn = $wb.basename;
say "Basename: '$bn'";

if $Debug {
    $wb.dump;
    say "DEBUG early exit after dump"; exit;
}

if $sheet > 1 and $ifil ~~ /:i csv/ {
    say "FATAL: Only one sheet in a csv file";
    exit;
}

print qq:to/HERE/;
Number of sheets: {$wb.sheets}
List of sheets:
HERE
my $i = 0;
for $wb.Sheet -> $s {
    ++$i;
    try say "  $i. '{$s.label}'";
    if $! {
        # the "first" sheet is Nil
        next;
    }
}

say "List of sheets by index:";
#has %.sheet   is rw;      # key: sheet name, value: index 1..N of N sheets
my @idx = 1..$wb.sheet.elems;
#for $wb.sheet.keys.sort -> $i {
for @idx -> $i {
    my $s = $wb.sheet{$i};
    try say "  $i. '{$s.label}'";
    if $! {
        # the "first" sheet is Nil
        next;
    }
}

