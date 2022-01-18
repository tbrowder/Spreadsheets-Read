unit module Spreadsheets::Classes;

use Text::Utils :normalize-string;

class Cell is export {
    # a Cell knows its array position
    has $.i is rw; # row index, zero-based
    has $.j is rw; # col index, zero-based

    #| holds a formatting object generated and used by Excel::Writer::XLSX
    has $.format is rw = '';

    has $.value is rw = '';
    has $.formatted-value is rw; # as reported by Spreadsheet::Read

    #| these data come from Spreadsheet::Read's 'attr' key's value
    #| which is an array of arrays of hashes
    has %.fmt is rw;

    method copy(:$no-value, :$debug) {
        #! returns a copy of this Cell object
        my $c = $no-value ?? Cell.new: :i($.i), :j($.j), :fmt(%.fmt), :format($.format)
                          !! Cell.new: :i($.i), :j($.j), :value($.value), :fmt(%.fmt), :format($.format);
        return $c;
    }
} # end of class Cell

class Row is export {
    has Cell @.cell; # an array of Cell objects

    method trim(:$debug) {
        while @.cell.elems {
            die "FATAL: cell object is NOT a Cell: {@.cell.raku}" if @.cell.tail !~~ Cell;
            =begin comment
            if not @.cell.tail.defined {
                note "DEBUG: cell tail is undefind, @.cell.raku: |{@.cell.raku}|";
                last
                @.cell.pop;
            }
            @.cell.pop and last if not @.cell.tail.defined;
            =end comment
            
            #note "DEBUG cell.tail.defined? {@.cell.tail.defined}";
            my $v = @.cell.tail.value // '';
            last if $v;
            @.cell.pop;
        }
    }

    method copy {
        # returns a copy of this Row object
    }
} # end of class Row

class Sheet is export {
    has Row @.row;      # an array of Row objects (each Row object has an array of Cell objects)
    has %.colrow;       # a hash indexed by Excel A1 label (col A, row 1)

    # single-value attributes
    has $.active is rw = 0;
    has $.indx   is rw = 0;
    has $.label  is rw = '';
    has $.maxcol is rw = 0; # in the input data, this is the last-used column, 1-based
    has $.maxrow is rw = 0; # in the input data, this is the last-used row, 1-based
    has $.mincol is rw = 0;
    has $.minrow is rw = 0;
    has $.parser is rw = '';
    # other attributes
    has @.attr   is rw; # array
    has @.merged is rw; # array

    has $.no-trim is rw = 0;

    method dump-csv {
        my $nrows = @.row.elems;
        say "$nrows rows";
        for @.row.kv -> $i, $row {
            say "row $i: {$row.cell.elems} cells";
        }
        say "==== $nrows rows";
        for @.row.kv -> $i, $row {
            my $ncols = $row.cell.elems;
            for $row.cell.kv -> $j, $c {
                print "," if $j;
                if $c ~~ Cell and $c.value {
                    print "{$c.value}";
                }
            }
            #say();
            say "    <-- # sheet $.indx, row $i, $ncols columns";
        }
    }

    method dump {
        say "dumping sheet $.indx";
        for @.row.kv -> $i, $row {
            say "  row $i";
            print "    ";
            for $row.cell.kv -> $j, $c {
                if $c and $c.value {
                    print " '{$c.value}'";
                }
                else {
                    print " '(empty)'";
                }
            }
            say();
        }
    }

    method add-cell-fmt-hash(%h, :$i, :$j, :$debug) {
        my $row = @.row[$i];
        if $row.cell[$j] {
            # add the hash
            $row.cell[$j].fmt = %h;
        }
        else {
            die "FATAL: no Cell object for row $i, col $j";
        }
    }

    method add-cell(Cell $c, :$debug) {
        my $i = $c.i;
        my $j = $c.j;

        # ensure we have rows for indices 0 through $i
        for 0..$i -> $idx {
            if not @.row[$idx] {
                my $r = Row.new;
                @.row[$idx] = $r;
            }
        }

        my $row = @.row[$i];
        if $row.cell[$j] {
             note "WARNING: cell $i, $j already exists";
        }
        else {
             $row.cell[$j] = $c;
        }
    }

    method add-cell-attrs(@attrs, :$debug) {
        if 0 and $debug {
            say "DEBUG: in sub add-cell-attrs, dumping raw input cell data";
            my $j = -1;
            shift @attrs; # elim empty col
            for @attrs -> $a {
               ++$j;
                say "col $j";
                if $a ~~ Any:U {
                    #say "1 skipping undefined object type {$a.^name}";
                    say "  skipping undefined column array";
                    next;
                }

                my @arr = @($a);
                shift @arr; # elim empty row
                my $i = -1;
                for @arr -> $c {
                    ++$i;
                    say "    row $i";

                    if $c ~~ Any:U {
                        #say "2 skipping undefined object type {$c.^name}";
                        say "      skipping undefined cell hash";
                        next;
                    }

                    for $c.keys.sort -> $k {
                         my $v = %($c){$k};
                         if $v ~~ Any:U {
                             say "       key '$k' => value 'Nil'";
                             next;
                         }
                         say "       key '$k' => value '$v'";
                    }
                    next;
                }
            }
            say "DEBUG: early exit";
            exit;
        }

        # First we'll make sure we can read the data.
        my $t = @attrs.^name;
        say "  incoming @attrs type: $t" if $debug;
        my $j = -1; # col index, zero-based
        my $nc = @attrs.elems;
        say "  \@attrs array has $nc elements" if $debug;
        @attrs.shift; # elim empty col
        for @attrs -> $col {
            $t = $col.^name;
            say "    col array element type: $t" if $debug;
            ++$j;
            say "    reading col $j" if $debug;
            # it may be undef
            my @colrows = @($col); # // Nil;
            @colrows.shift; # elim empty row
            if @colrows ~~ Any:D {
                # an empty column
                say "    (empty column array)" if $debug;
            }
            else {
                # one or more cells
                my $nr = @colrows.elems;
                $t = @colrows.^name;
                say "    colrows type: $t (with $nr elements)" if $debug;
                my $i = -1; # row index, zero-based
                for @colrows -> $rowcell {
                    $t = $rowcell.^name;
                    ++$i;
                    # it may be undef
                    my %h = %($rowcell) // Nil;
                    if %h ~~ Any:U {
                        say "      skipping undefined cell hash $i (type $t)" if $debug;
                        next;
                    }
                    if $debug {
                        say "      dumping cell hash $i (type $t)" if $debug;
                        for %h.kv -> $k, $v {
                            if $v ~~ Any:U {
                                say "       key '$k' => value 'Nil'";
                                next;
                            }
                            say "       key '$k' => value '$v'";
                        }
                    }
                    # add the hash to the proper Cell object
                    self.add-cell-fmt-hash: %h, :$i, :$j, :$debug;
                }
            }
        }
    }

    method add-cell-data(@cols, :$debug) {

        if 0 and $debug {
        #if 1 {
            my $nr = @cols.elems;
            say "DEBUG: in sub add-cell-data, dumping raw input cell data for $nr cols";
            if 0 {
                say @cols.gist;
                say @cols.raku;
                say "DEBUG: early exit"; exit;
            }

            shift @cols; # elim empty col
            my $j = -1;
            for @cols -> $a {
                ++$j;
                say "col $j";
                if not $a or $a ~~ Any:U {
                    say "(Nil col)";
                    next;
                }
                my @a = @($a);
                shift @a; # elim empty row
                for @a -> $b {
                    my $v = $b // '|';
                    $v = normalize-string $v if $v ~~ Str;
                    $v = '|' if $v eq '';
                    print " $v";
                }
                say();
            }
            say "DEBUG: early exit"; exit;
        }

        # First we'll make sure we can read the data.  We want
        # undefined cells to have empty values.  Keep track of max
        # number of cells in a row:
        # TODO explain why col 0 is empty
        @cols.shift; # elim empty col
        my $max = 0;
        my $t = @cols.^name;
        say "  incoming cols type: $t" if $debug;
        my $j = -1; # col index, zero-based
        my $nc = @cols.elems;
        say "  \@cols array has $nc elements" if $debug;
        for @cols -> $col {
            $t = $col.^name;
            say "    col array element type: $t" if $debug;
            ++$j;
            say "    reading col $j" if $debug;
            # it may be undef
            my @colrows = @($col); # // [];
            # TODO explain why colrows 0 is empty
            @colrows.shift; # elim empty row cell
            my $nr = @colrows.elems;
            if @colrows ~~ Any:U {
                # an empty column
                say "    (empty column array)" if $debug; #
                next;
            }
            # one or more cells
            $t = @colrows.^name;
            say "    colrows type: $t (with $nr elements)" if $debug;
            my $i = -1; # row index, zero-based
            for @colrows -> $rowcell {
                $t = $rowcell.^name;
                ++$i;
                ++$max if $i > $max;
                # it may be undef
                my $cell = $rowcell // Nil;
                my $c = Cell.new: :$i, :$j;
                $c.value = $cell unless $cell ~~ Any:U; #eq '(empty)';
                self.add-cell: $c;
                if $debug {
                    say "      reading cell $i, $j";
                    say "      orginal cell type: $t";
                    my $val = $cell // 'Nil';
                    say "      cell value: '$val'";
                }
            }
        }

        =begin comment
        # DO NOT USE THIS CODE
        # TODO why does dump-csv add cells that shouldn't be there?
        # trim empty cells from each row
        if not $.no-trim {
            ; # delete empty trailing empty cells
            for self.row -> $row {
                #note "DEBUG: gisting row: |{$row.gist}|";
                $row.trim;
            }
        }
        =end comment

    }

    #| check for and handle Excel colrow ids
    method add-colrow-hash($k, $v) {
        %.colrow; # a hash indexed by Excel A1 label (col A, row 1)
        if %.colrow{$k}:exists {
            note "WARNING: Excel A1 id '$k' is a duplicate";
        }
        else {
            %!colrow{$k} = $v;
        }
    }

    method dump-colrows(:$debug) {
        for %.colrow.keys.sort -> $k {
            my $v = %.colrow{$k};
            note "rolcow: $k, value: $v" if $debug;
        }
    }

    method copy {
        # returns a copy of this Sheet object
    }

} # end of class Sheet

