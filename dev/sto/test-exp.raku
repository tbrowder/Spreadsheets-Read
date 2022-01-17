#!/usr/bin/env raku

use lib <../lib>;
use Top::Class;
#use Top;

=finish

my $o = Bar.new;
say $o.foo.id;

$o = Top.new;
say $o.foo.id;
