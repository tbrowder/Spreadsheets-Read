#!/usr/bin/env raku

my @pkgs = <
libspreadsheet-read-perl
libspreadsheet-parseexcel-perl
libspreadsheet-parsexlsx-perl
libspreadsheet-readsxc-perl

libtext-csv-perl

libexcel-writer-xlsx-perl
>;

for @pkgs {
    #shell "aptitude versions $_";
    shell "apt show $_";
    #shell "apt-cache showpkg --version $_";
}
