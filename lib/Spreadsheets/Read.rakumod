use Spreadsheets::Workbook;
use Spreadsheets::XLSX-Utils;

unit class Spreadsheets::Read is Workbook;

has $.file is required;
has $.wb;
has $.debug = 0;

method new($fname, :$debug) {
    die "FATAL: '$fname' is NOT a file" if not $fname.IO.r;
    self.bless(:file($fname), :debug($debug))
}

submethod TWEAK {
    $!wb = Workbook.new: :file($!file.Str), :debug($!debug)
}


