use strict;
use warnings;

use Test::More;
use Test::Moose;

use ok 'KiokuDB::Serializer';
use ok 'KiokuDB::Serializer::CSV';

use ok 'KiokuDB::Entry';

sub KiokuDB::Entry::BUILD { shift->root }; # force building of root for is_deeply
$_->make_mutable, $_->make_immutable for KiokuDB::Entry->meta; # recreate new

my $expect_entry = KiokuDB::Entry->new(
    class => 'Foo',
    data => {
        first_name => 'Nobody',
        last_name => 'Inparticular',
        email => 'foo@bar.com',
        password => '{SSHA}AhHgDcFyIwxAtzRtCubJeqc7rJPY1rgStmioZylvOix/w-3NvDGoCQ==',
        datetime => 1264007615,
        verified => 1,
        agree_tos => 1,
    });

my $expect_buf = <<EOC;
"class","email","password","verified","agree_tos","datetime","last_name","first_name"
"Foo","foo\@bar.com","{SSHA}AhHgDcFyIwxAtzRtCubJeqc7rJPY1rgStmioZylvOix/w-3NvDGoCQ==","1","1","1264007615","Inparticular","Nobody"
"Foo","foo\@bar.com","{SSHA}AhHgDcFyIwxAtzRtCubJeqc7rJPY1rgStmioZylvOix/w-3NvDGoCQ==","1","1","1264007615","Inparticular","Nobody"
"Foo","foo\@bar.com","{SSHA}AhHgDcFyIwxAtzRtCubJeqc7rJPY1rgStmioZylvOix/w-3NvDGoCQ==","1","1","1264007615","Inparticular","Nobody"
EOC

{
    my $s_csv = KiokuDB::Serializer::CSV->new;
    my $entry = KiokuDB::Entry->new(
        class => 'Foo',
        data => {
            first_name => 'Nobody',
            last_name => 'Inparticular',
            email => 'foo@bar.com',
            password => KiokuDB::Entry->new( class => 'Authen::Passphrase::SaltedDigest', data => '{SSHA}AhHgDcFyIwxAtzRtCubJeqc7rJPY1rgStmioZylvOix/w-3NvDGoCQ==' ),
            datetime => KiokuDB::Entry->new( class => 'DateTime', data => 1264007615 ),
            verified => 1,
            agree_tos => 1,
        });

    does_ok( $s_csv, "KiokuDB::Serializer" );
    does_ok( $s_csv, "KiokuDB::Backend::Serialize" );

    my $ser = $s_csv->serialize( $entry );
    ok( !ref($ser), "non ref" );
    ok( length($ser), "got data" );

    is_deeply( $s_csv->deserialize($ser), $expect_entry, "round tripping" );

    $s_csv->seen_headers(0); ## HACK

    my $buf = '';
    open my $out, ">", \$buf;
    $s_csv->serialize_to_stream($out, $entry) for 1 .. 3;
    close $out;

    ok( length($buf), "serialize_to_stream" );
    is( $buf, $expect_buf, "serialize_to_stream" );

=cut
    open my $in, "<", \$buf;

    my @entries;

    my $n;

    while ( my @got = $s_csv->deserialize_from_stream($in) ) {
        $n++;
        push @entries, @got;
    }

    is( scalar(@entries), 3, "three entries from stream ($n reads)" );

    isa_ok( $_, "KiokuDB::Entry" ) for @entries;

    is_deeply( $entries[0], $entry, "round tripping" );
=cut
}

done_testing;
