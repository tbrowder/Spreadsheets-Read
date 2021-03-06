unit module Spreadsheets::Utils;

use Text::Utils :normalize-string;

constant $SPACES = '    ';

#### subroutines ####
sub dump-array(@a, :$level is copy = 0, :$debug) is export {
    my $sp = $level ?? $SPACES x $level !! '';
    for @a.kv -> $i, $v {
        my $t = $v.^name;

        print "$sp index $i, value type: $t";
        if $t ~~ /Hash/ {
            my $ne = $v.elems;
            say ", num elems: $ne";
            dump-hash $v, :level(++$level), :$debug;
        }
        elsif $t ~~ /Array/ {
            # we may have an undef array
            my $val = $v // '';
            if $val {
                my $ne = $v.elems;
                say ", num elems: $ne";
                dump-array $v, :level(++$level), :$debug;
            }
            else {
                say();
                say "$sp   (undef array)";
            }
        }
        else {
            say();
            my $s = $v // '';
            say "$sp   value: '$s'";
        }
    }
} # sub dump-array

sub dump-hash(%h, :$level is copy = 0, :$debug) is export {
    my $sp = $level ?? $SPACES x $level !! '';
    for %h.keys.sort -> $k {
        my $v = %h{$k} // '';
        my $t = $v.^name;


        if $k ~~ /^ (<[A..Z]>+) (<[1..9]> <[0..9]>?) $/ {
            # collect the Excel A1 hashes
            my $col = ~$0;
            my $row = +$1;
            my $colrow = $col ~ $row.Str;

            note "DEBUG: found A1 Excel colrow id: '$k'" if $debug;
            if $t !~~ Str {
                note "WARNING: its value type is not Str it's: $t";
            }
            else {
                note "  DEBUG: with value: '$v'" if $debug;

=begin comment
                # need to confirm sheet num and its existence
                my $s = $wb.sheet[$sheet-1];

                # insert key and val in the sheet's %colrow hash
                $s.colrow{$k} = $v;
=end comment
            }
        }
        elsif $k eq 'cell' {
            # collect the cell[col][row] values
        }

        say "$sp key: $k, value type: $t";
        if $t ~~ /Hash/ {
            dump-hash $v, :level(++$level), :$debug;
        }
        elsif $t ~~ /Array/ {
            # we may have an undef array
            my $val = $v // '';
            if $val {
                dump-array $v, :level(++$level), :$debug;
            }
            else {
                say "$sp   (undef array)";
            }
        }
        else {
            my $s = $v // '';
            say "$sp   value: '$s'";
        }
    }
} # sub dump-hash

=begin comment
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

sub get-typ-and-val($v, :$debug) is export {
    # Determines the type of $v, then converts
    # $v to either a string with value 'undef'
    # or retains its value.
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

sub colrow2cell($a1-id, :$debug) is export {
    # Given an Excel A1 style colrow id, transform it to zero-based
    # row/col form.
    my ($i, $j);


    return $i, $j;
} # sub colrow2cell
=end comment
