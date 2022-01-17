#!/usr/bin/env raku

#use lib <../lib>;
#use Spreadsheets;

my @f =
"../t/data/sample-security-sales.xlsx",
"../t/data/sample-security-sales.xls",
"../t/data/sample-security-sales.ods",
"../t/data/sample-security-sales.csv",
"../t/data/mytest.csv",
;

if !@*ARGS.elems {
    say qq:to/HERE/;
    Usage: {$*PROGRAM.basename} 1|2|3|4|5 
    
    Uses the Perl module Spreadsheet::Read and 
    inspects data from the selected file number:
    HERE
    my $n = 0;
    for @f -> $f {
        ++$n;
        say "  $n. {$f.IO.basename}";
    }
    exit;
}

my $n;
for @*ARGS {
    when /(1|2|3|4|5)/ { 
        $n = +$0 - 1 
    }
    default {
        say "FATAL: Unhandled arg '$_'";
        exit;
    }
}

my $ifil = @f[$n];

=begin comment
use Spreadsheet::Read:from<Perl5>;
my $wb = Spreadsheet::Read.new($ifil) ;
my %sheet = %($wb.sheet(1));
say %sheet.gist;
say "The above data were in file '@f[$n]'";
=end comment

my $h = get-hash $ifil;
say $h.gist;
say "The above data were in file '$ifil'";

### SUBROUTINES ###
sub get-hash($file, :$debug) {
    use Spreadsheet::Read:from<Perl5>;
    my $h = ReadData $file, :attr;
    return $h;
}

