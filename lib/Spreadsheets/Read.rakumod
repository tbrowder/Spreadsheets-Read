use Spreadsheets::Workbook;
use Spreadsheets::XLSX-Utils;

unit class Spreadsheets::Read is Workbook;


has $.file is required;
has $.wb;
has $.debug = 0;;

method new($fname, :$debug) {
    self.bless(:file($fname))
}

submethod TWEAK {
    $!wb = Workbook.new: :file($!file), :debug($!debug)
}


