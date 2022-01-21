use lib <../lib>;

class Foo {
    has @.arr is rw = ();
}

my \s = Foo.new;
s.arr.push: 1;
say s.raku;

say s.arr[0];



