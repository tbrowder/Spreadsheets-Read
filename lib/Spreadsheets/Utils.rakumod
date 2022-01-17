unit module Spreadsheets::Utils;

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

class Workbook is export {
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
    # input file attrs:
    has $.file     = '';
    has $.basename = '';
    has $.path     = '';

    method new($fname) {
        self.bless(:file($fname))
    }

    submethod TWEAK {
    }

    method read(:$file!, :$debug) {
        #! make sure the file isn't already in the hash
        my $basename = $file.IO.basename;
        my $path     = $file.IO.absolute;
        if %.files{$basename}:exists {
            note "WARNING: File '$file' has already been read or written.";
            return;
        }
        if !$path.IO.f {
            note "FATAL: File '$file' cannot be read.";
            exit;
        }

        my $wb = Workbook.new: :$basename, :$path;
        @.sources.push: $wb;

        # figure out the correct workbook object to use
        %.files{$basename}<path>         = $path;
        # use "@.sources.tail" for the last object, use "@.sources.end" for the last index number
        %.files{$basename}<source-index> = @.sources.end;
        %.files{$basename}<written> = 1;

        collect-file-data(:$path, :$wb, :$debug);
    }

    #method dump(:$index!, :$debug) {
    method dump(:$debug) {
        #say "DEBUG: dumping workbook index $index, file basename: {$.basename}";
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
            }
        }

    }

    method copy {
        # returns a copy of this Workbook object
    }

} # end of class Workbook


class WorkbookSet is export {
    use Spreadsheet::Read:from<Perl5>;


    #| an array of "immutable" input Workbook objects that can be written again under a new name
    has Workbook @.sources;
    #   use "@.sources.tail" for the last object, use "@.sources.end" for the last index number

    #| a hash of info on files read or written and their associated Workbook locations
    has %.files;

    #| an array of Workbook objects capable of being written
    has Workbook @.products;
    #   use "@.products.tail" for the last object, use "@.products.end" for the last index number

    method dump(:$debug) {
        my $ns = @.sources.elems;
        my $np = @.products.elems;
        my $s = $ns > 1 ?? 's' !! '';
        say "DEBUG: dumping WorkbookSet containing:";
        say "          $ns source workbook$s...";
        for @.sources.kv -> $i, $wb {
            $wb.dump: :index($i), :$debug;
        }
        $s = $np > 1 ?? 's' !! '';
        if $np {
            say "          and $np product workbook$s...";
        }
        else {
            say "          and no product workbooks.";
        }
    }

    method write(:$file!, Workbook :$template, :$force, :$debug) {
        #! for now only xlsx files can be written
        if $file !~~ /'.xlsx'$/ {
            note "FATAL: Output files MUST be xlsx format with '.xlsx' file extension.";
            note "       You chose '$file'";
            exit;
        }
        # make sure the file isn't already in the hash
        my $basename = $file.IO.basename;
        my $path     = $file.IO.absolute;
        if %.files{$basename}:exists {
            note "WARNING: File '$file' has already been read or written.";
            return;
        }
        if !$path.IO.f {
            note "FATAL: File '$file' cannot be read.";
            exit;
        }
    }

    method read(:$file!, :$debug) {
        #! make sure the file isn't already in the hash
        my $basename = $file.IO.basename;
        my $path     = $file.IO.absolute;
        if %.files{$basename}:exists {
            note "WARNING: File '$file' has already been read or written.";
            return;
        }
        if !$path.IO.f {
            note "FATAL: File '$file' cannot be read.";
            exit;
        }

        my $wb = Workbook.new: :$basename, :$path;
        @.sources.push: $wb;

        # figure out the correct workbook object to use
        %.files{$basename}<path>         = $path;
        # use "@.sources.tail" for the last object, use "@.sources.end" for the last index number
        %.files{$basename}<source-index> = @.sources.end;
        %.files{$basename}<written> = 1;

        collect-file-data(:$path, :$wb, :$debug);
    }

} # class WorkbookSet

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

sub collect-file-data(:$path, Workbook :$wb!, :$debug) is export {
    use Spreadsheet::Read:from<Perl5>;

    #my $pbook = ReadData $path, :attr, :clip, :strip(3); # array of hashes
    #my $pbook = Spreadsheet::Read::ReadData($path, 'attr' => 1, 'clip' => 1, 'strip' => 3); # array of hashes
    #my $pbook = Spreadsheet::Read::ReadData($path, 'clip' => 1, 'strip' => 3); # array of hashes
    my $pbook = Spreadsheet::Read::ReadData($path, 'clip' => 1, 'strip' => 3, 'debug' => 1); # array of hashes

    my $ne = $pbook.elems;
    say "\$book has $ne elements indexed from zero" if $debug;
    my %h = $pbook[0];
    collect-book-data %h, :$wb, :$debug;

=begin comment
my @rows = Spreadsheet::Read::rows($pbook[1]<cell>);
say @rows.gist;
#say "DEBUG exit";exit;
=end comment

    # get all the sheet data
    for 1..^$ne -> $index {
        %h    = $pbook[$index];
        my $s = Sheet.new;
        $wb.Sheet.push: $s;
        collect-sheet-data %h, :$index, :$s, :$debug;
    }
} # sub collect-file-data

#| Given the zeroth hash from Spreadsheet::Read and a
#| Workbook object, collect the meta data for the workbook.
sub collect-book-data(%h, Workbook :$wb!, :$debug) is export {

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
            $wb.error = $v;
        }
        elsif $k eq 'parser' {
            ++%keys-seen{$k};
            $wb.parser = $v;
        }
        elsif $k eq 'quote' {
            ++%keys-seen{$k};
            $wb.quote = $v;
        }
        elsif $k eq 'sepchar' {
            ++%keys-seen{$k};
            $wb.sepchar = $v;
        }
        elsif $k eq 'sheets' {
            ++%keys-seen{$k};
            $wb.sheets = $v;
        }
        elsif $k eq 'type' {
            ++%keys-seen{$k};
            $wb.type = $v;
        }
        elsif $k eq 'version' {
            ++%keys-seen{$k};
            $wb.version = $v;
        }
        # special handling required
        elsif $k eq 'sheet' {
            ++%keys-seen{$k};
            $wb.sheet = get-wb-sheet-hash $v;
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
    if not $wb.parser {
        ++$err;
        note "WARNING: no 'parser' found in meta data";
    }
    if not $wb.type {
        ++$err;
        note "WARNING: no 'type' found in meta data";
    }
    if not $wb.version {
        ++$err;
        note "WARNING: no 'version' found in meta data";
    }
    if $err {
        note "POSSIBLE BAD READ OF FILE '$wb.path' PLEASE FILE AN ISSUE";
    }


} # sub collect-book-data

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
