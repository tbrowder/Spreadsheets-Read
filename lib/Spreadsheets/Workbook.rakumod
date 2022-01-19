unit class Spreadsheets::Workbook is export;

use Spreadsheets::Classes;
use Spreadsheets::Utils;
use Text::Utils :normalize-string;

use Spreadsheet::Read:from<Perl5>;

# keys in the meta hash (book[0])
#   with string values
has $.quote   is rw = ''; # used for csv
has $.sepchar is rw = ''; # used for csv
has $.error   is rw = '';
has $.sheets  is rw;      # number of sheets

has $.parser  is rw;      # name of parser used
has $.type    is rw;      # of the parser used: xlsx, xls, csv, etc.
has $.version is rw;      # of the parser used
#   with array or hash values
has %.sheet   is rw;      # key: sheet name, value: index 1..N of N sheets

has $.no-trim is rw = 0; # default behavior is to trim trailing empty cells from each row

# the following appears to be redundant and will be ignored on read iff it
# only contains one element
#has @.parsers is rw;      # array of parser pairs hashes, keys: name, type, version

# convenience attrs
has Sheet @.Sheet; # array of Sheet objects
# input attrs:
has $.file is required;
has $.debug;

has $.basename;

submethod TWEAK {
    $!basename = $!file.IO.basename;
    self.read($!file)
}

method read($file) {
    my $path = $file.IO.absolute // die "WARNING: no valid path";
    if !$path.IO.f {
        note "FATAL: File '$file' cannot be read.";
        exit;
    }

    self.collect-file-data(:$path);
}

method dump {
    say "DEBUG: dumping workbook, file basename: {$.basename}";
    say "  == \%.sheet hash:";
    for %.sheet.keys.sort -> $k {
        my $v = %.sheet{$k};
        say "    '$k' => '$v'";
    }
    say "DEBUG: dumping sheet row/cols";
    my $i = 0;
    for @.Sheet -> $s {
        ++$i;
        say "=== sheet $i...";
        #$s.dump;
        try {
            $s.dump-csv;
        }
        if $! {
            say "=== one or more failures while dumping sheet $i...";
            say $!.Str;
        }
    }
}

method copy {
    # returns a copy of this Workbook object
}

method collect-file-data(
    :$path, 
    #Workbook :$wb!, 
    :$debug) is export {
    use Spreadsheet::Read:from<Perl5>;

    #my $pbook = ReadData $path, :attr, :clip, :strip(3); # array of hashes
    #my $pbook = Spreadsheet::Read::ReadData($path, 'attr' => 1, 'clip' => 1, 'strip' => 3); # array of hashes
    #my $pbook = Spreadsheet::Read::ReadData($path, 'clip' => 1, 'strip' => 3); # array of hashes
    my $pbook = Spreadsheet::Read::ReadData($path, 'clip' => 1, 'strip' => 3, 'debug' => 1); # array of hashes

    my $ne = $pbook.elems;
    say "\$book has $ne elements indexed from zero" if $debug;
    my %h = $pbook[0];
    #collect-book-data %h, :$wb, :$debug;
    self.collect-book-data(%h, :$debug);

=begin comment
my @rows = Spreadsheet::Read::rows($pbook[1]<cell>);
say @rows.gist;
#say "DEBUG exit";exit;
=end comment

    # get all the sheet data
    for 1..^$ne -> $index {
        %h    = $pbook[$index];
        my $s = Sheet.new;
        #$wb.Sheet.push: $s;
        $.Sheet.push: $s;
        #self.collect-sheet-data(%h, :$index, :$s, :$debug);
        collect-sheet-data(%h, :$index, :$s, :$debug);
    }

} # method collect-file-data

#| Given the zeroth hash from Spreadsheet::Read and a
#| Workbook object, collect the meta data for the workbook.
method collect-book-data(%h, :$debug) {

    constant %known-keys = [
        error    => 0,
        quote    => 0,
        sepchar  => 0,
        sheets   => 0,

        parser   => 0,
        type     => 0,
        version  => 0,

        parsers  => 0, # not used at the moment as it appears to be redundant
        sheet    => 0,
    ];

    my %keys-seen = %known-keys;
    say "DEBUG: collecting book meta data..." if $debug;
    for %h.kv -> $k, $v {
        say "  found key '$k'..." if $debug;
        note "WARNING: Unknown key '$k' in workbook meta data" unless %known-keys{$k}:exists;
        if $k eq 'error' {
            ++%keys-seen{$k};
            $.error = $v;
        }
        elsif $k eq 'parser' {
            ++%keys-seen{$k};
            $.parser = $v;
        }
        elsif $k eq 'quote' {
            ++%keys-seen{$k};
            $.quote = $v;
        }
        elsif $k eq 'sepchar' {
            ++%keys-seen{$k};
            $.sepchar = $v;
        }
        elsif $k eq 'sheets' {
            ++%keys-seen{$k};
            $.sheets = $v;
        }
        elsif $k eq 'type' {
            ++%keys-seen{$k};
            $.type = $v;
        }
        elsif $k eq 'version' {
            ++%keys-seen{$k};
            $.version = $v;
        }
        # special handling required
        elsif $k eq 'sheet' {
            ++%keys-seen{$k};
            %.sheet = get-wb-sheet-hash $v;
        }
        # special handling required
        elsif $k eq 'parsers' {
            ++%keys-seen{$k};
            # This appears to be redundant and will
            # be ignored as long as it only contains
            # one element. The one element is an anonymous
            # hash of three key/values (parser, type, version), all
            # which are already single-value attributes.
            my $ne = $v.elems;
            if $ne != 1 {
                die "FATAL: Expected one element but got $ne elements";
            }
        }
    }

    # ensure we have the parser, type, and version values as a sanity
    # check on our understanding of the read data format
    my $err = 0;
    if not $.parser {
        ++$err;
        note "WARNING: no 'parser' found in meta data";
    }
    if not $.type {
        ++$err;
        note "WARNING: no 'type' found in meta data";
    }
    if not $.version {
        ++$err;
        note "WARNING: no 'version' found in meta data";
    }
    if $err {
        note "POSSIBLE BAD READ OF FILE '$.path' PLEASE FILE AN ISSUE";
    }


} # method collect-book-data

sub get-wb-parsers-array($v) is export {
    my $t = $v.^name; # expect Perl5 Array
    my @a;
    my $val = $v // '';

    if $t ~~ /Array/ {
        if $val {
           for $val -> $v {
               my $t = $v.^name; # expect Perl5 Hash
               my $ne = $v.elems;
               note "DEBUG: element of parsers array is type: '$t'";
               note "       it has $ne element(s)";
               my $V = $v // '';
               @a.push: $V;
           }
        }
        else {
            note "array is empty or undefined";
        }
        return @a;
    }
    die "FATAL: Unexpected non-array type '$t'";
} # sub get-wb-parsers-array

sub get-wb-sheet-hash($v) is export {
    my $t = $v.^name; # expect Perl5 Hash
    my %h;
    my $val = $v // '';

    if $t ~~ /Hash/ {
        if $val {
           for $val.kv -> $k, $v {
               %h{$k} = $v;
           }
        }
        return %h;
    }
    die "FATAL: Unexpected non-hash type '$t'";
} # sub get-wb-sheet-hash

#| Given the sheet's original index, i, the ith hash
#| from Spreadsheet::Read and a Sheet object, collect
#| the data for the sheet.
sub collect-sheet-data(%h, :$index, Sheet :$s!, :$debug) is export {
    constant %known-keys = [
        # single-value attributes
        active   => 0,
        indx     => 0,
        label    => 0,
        maxcol   => 0,
        maxrow   => 0,
        mincol   => 0,
        minrow   => 0,
        parser   => 0,
        # other attributes
        attr     => 0, # array
        merged   => 0, # array
        cell     => 0, # M x N array
    ];

    my %keys-seen = %known-keys;

    # Since we can't ensure the 'cell' arrays
    # are read before the 'attr' arrays, we
    # save its value here and read it after
    # all other keys are seen.
    my $attr = 0;
    for %h.kv -> $k, $v {
        if $k ~~ /^ (<[A..Z]>+) (<[1..9]> <[0..9]>?) $/ {
            # check for and handle Excel colrow ids
            $s.add-colrow-hash: $k, $v;
            next;
        }

        note "WARNING: Unknown key '$k' in spreadsheet data" unless %known-keys{$k}:exists;

        if $k eq 'active' {
            ++%keys-seen{$k};
            $s.active = $v;
        }
        elsif $k eq 'attr' {
            # a 2x2 array of various types
            ++%keys-seen{$k};
            # save the value for later handling
            $attr = $v;
            next;

            my ($t, $vv, $ne) = get-typ-and-val $v;
            # this SHOULD be an array OR undef
            say "DEBUG dumping type $t with $ne elements";
            # col first
            my $j = -1;

            my $a = $vv;
            if $t !~~ /Array|Hash/ {
               die "Unexpected type $t";
            }
            if $t ~~ /Array/ {
                dump-array $a, :$debug;
                say "DEBUG: early exit";exit;
            }

            for $a -> $b {
                ++$j;
                ($t, $vv, $ne) = get-typ-and-val $b;
                say "    dumping type $t with $ne elements";

                my $aa = $a // '';
                $t = $aa.^name;
                if $t !~~ /Hash|Str|Any|Array/ {
                    note "unexpected attr type $t";
                    say "DEBUG early exit";exit;
                }
                else {
                    say "    got type: $t";
                }
                if $t ~~ /Str/ {
                    say "    gisting string at col $j:";
                    say $aa.gist;
                    next;
                }

                my @a = @($a) // [];
                my $n = @a.elems;
                say "  array $j consisting of $n hash elements";
                my $i = -1;
                for @a -> $b {
                    ++$i;
                    $t = $b.^name;
                    if $t !~~ /Hash|Str|Any|Array/ {
                        note "unexpected attr type $t";
                        say "DEBUG early exit";exit;
                    }
                    else {
                        say "    got type: $t";
                    }

                    my $c = $b // '';
                    $t = $c.^name;
                    if $t ~~ /Array/ {
                        say "    gisting array at $i,$j:";
                    }
                    elsif $t ~~ /Str/ {
                        say "    gisting string at $i,$j:";
                        say $c.gist;
                        next;
                    }
                    elsif $t ~~ /Hash/ {
                        say "    gisting hash at $i,$j:";
                        say $c.gist;
                        next;
                    }
                    else {
                        note "unexpected attr type $t";
                        say "DEBUG early exit 2";exit;
                    }

                    my @c = @($c);
                    for @c -> $d {
                        $t = $d.^name;
                        say "      \$d element type: $t":
                        my $e = $d // '';
                        $t = $e.^name;
                        if $t ~~ /Hash/ {
                            my %h = %($e) // %();
                            for %h.keys.sort -> $k {
                                my $v = %h{$k};
                                say "      '$k' => '$v'";
                            }
                        }
                        elsif $t ~~ /Hash/ {
                            my %h = %($e) // %();
                            for %h.keys.sort -> $k {
                                my $v = %h{$k};
                                say "      '$k' => '$v'";
                            }
                        }
                    }
                    #print "    '$val'";
                }
                say();
            }

            $s.attr = $v;
            #say $v.raku;
            say "DEBUG early exit";exit;
        }
        elsif $k eq 'cell' {
            ++%keys-seen{$k};
            # a 2x2 aray
            # the arrays here will be transformed to this module's row/col array
            $s.add-cell-data: $v, :$debug;
        }
        elsif $k eq 'indx' {
            ++%keys-seen{$k};
            $s.indx = $v;
        }
        elsif $k eq 'label' {
            ++%keys-seen{$k};
            $s.label = $v;
        }
        elsif $k eq 'maxcol' {
            ++%keys-seen{$k};
            $s.maxcol = $v;
        }
        elsif $k eq 'maxrow' {
            ++%keys-seen{$k};
            $s.maxrow = $v;
        }
        elsif $k eq 'merged' {
            # an array
            ++%keys-seen{$k};
            $s.merged = $v;
        }
        elsif $k eq 'mincol' {
            ++%keys-seen{$k};
            $s.mincol = $v;
        }
        elsif $k eq 'minrow' {
            ++%keys-seen{$k};
            $s.minrow = $v;
        }
        elsif $k eq 'parser' {
            ++%keys-seen{$k};
            $s.parser = $v;
        }
        else {
            note "WARNING: Unknown key '$k'";
        }
    }

    # now we add the 'attr' data if it's available
    $s.add-cell-attrs($attr, :$debug) if $attr;

    # First check our assumptions are correct: The array should be
    # rectangular.
    # TODO or should that be an option?
    my $maxcol = 0;
    my $i = -1;
    my $err = 0;
    my $warn = 0;
    for $s.row -> $r {
        ++$i;
        my $nc = $r.cell.elems;
        $maxcol = $nc if $i == 0;
        if $nc != $maxcol {
            ++$warn;
            say "WARNING: row $i has $nc elements but \$maxcol is $maxcol elements" if 0 and $debug;
        }
    }

    if 0 and $debug {
        say "DEBUG: early exit";
        exit;
    }

} # sub collect-sheet-data

#| Given a cell array from Spreadsheet::Read and a
#| Sheet object, collect the data for the sheet. In
#| the process, convert the data into rows of cells
#| with zero-based indexing.
sub collect-cell-data($cell, Sheet :$s!, :$debug) is export {
} # sub collect-cell-data

#| Determines the type of $v, then converts
#| $v to either a string with value 'undef'
#| or retains its value.
sub get-typ-and-val($v, :$debug) is export {
    my $t = $v.^name;
    my $vv = $v // 'undef';
    $t = $vv.^name;
    my $ne = $vv.elems;
    if $t !~~ /Hash|Str|Int|Num|Array/ {
        note "unexpected attr type $t";
        note "DEBUG early exit";
        die "FATAL";
    }
    return ($t, $vv, $ne);
} # sub get-typ-and-val

#| Given an Excel A1 style colrow id, transform it to zero-based
#| row/col form.
sub colrow2cell($a1-id, :$debug) is export {
    my ($i, $j);

    #                    column           row
    if $a1-id ~~ /^ :i (<[a..z]>+) (<[1..9]> <[0..9]>*) $/ {
        my $a = ~$0; # column value
        my $b = +$1; # row value
        # TODO convert the pieces to row-col zero-indexed
    }
    else {
        die "ERROR: Invalid A1 format: '$a1-id'"
    }

    $i, $j
} # sub colrow2cell

#| (4) => (D)
sub col2label(Int $col is copy where $col > 0) is export {
    my $label = "";
    while $col {
        $label.substr-rw(0, 0) = chr(--$col mod 26 + ord("A"));
        $col = $col div 26;
    }
    $label
} # sub col2label

#| (D) => (4)
sub label2col($label is copy where $label ~~ /^:i <[A..Z]>+$/) is export {
    $label .= uc;
    my $col = 0;
    while $label ~~ s/^(<[A..Z]>)// {
        $col = 26 * $col + 1 + ord(~$0) - ord("A");
    }
    $col
} # sub label2col


