#! /usr/bin/perl

use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More;
use t::util::Util;

my @files = @ARGV;

@files = <t/run/*.jsx>
    unless @files;

plan tests => scalar @files;

run($_)
    for @files;

sub run {
    my $file = shift;
    local $TODO = 'not yet' if  ($file =~ /\.todo\.jsx$/);

    defined(my $expected = get_expected($file))
        or die "could not find EXPECTED in file:$file\n";
    my $tempdir = tempdir(CLEANUP => 1);

    # compile (FIXME support C++)
    system("bin/jsx $file > $tempdir/compiled.js") == 0
        or return fail("compile failed: $?");

    # add the bootstrap code
    {
        open my $fh, ">>", "$tempdir/compiled.js"
            or die "failed to open file:$tempdir/compiled.js:$!";
        print $fh <<'EOT';
// workaround for node.js to set "JSX" to global
(function () { return this; })().JSX = JSX;
// invoke the test
try {
    Test.run$();
} catch (e) {
    console.log(e.message.replace(/^\[.*?\]\s*/, ""));
}
EOT

    }

    # execute compiled node
    my $output = do {
        open my $fh, "-|", "node $tempdir/compiled.js"
            or die "failed to invoke node:$!";
        local $/;
        my $ret = <$fh>;
        close $fh;
        return fail "failed to execute compiled script"
            if $? != 0;
        $ret;
    };

    # compare the results
    is $output, $expected, $file;
}
