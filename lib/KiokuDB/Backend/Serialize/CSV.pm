package KiokuDB::Backend::Serialize::CSV;
use Moose::Role;
use Moose::Util::TypeConstraints qw(match_on_type);
use IO::Handle;
use Text::CSV;
use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Backend::Serialize
    KiokuDB::Backend::Role::UnicodeSafe
    KiokuDB::Backend::TypeMap::Default::Storable
);

has csv => (
    isa => 'Object',
    is  => 'rw',
    lazy_build => 1,
    handles => [ qw( combine parse string getline print column_names ) ],
);

sub _build_csv {
    my $self = shift;

    my $csv = Text::CSV->new(
    {  
        quote_char          => '"',
        escape_char         => '"',
        sep_char            => ',',
        eol                 => "\n",
        binary              => 1,
        allow_loose_quotes  => 1,
        allow_loose_escapes => 1,
        allow_whitespace    => 1,
        always_quote        => 1
    });

    return $csv;
}

sub serialize {
    my ( $self, $entry ) = @_;

    my ( @headings, @fields, $row, $data );

    $data = $entry->data;

    if ( defined $entry->id ) {
        push @headings, 'id';
        push @fields, $entry->id;
    }

    push @headings, 'class';
    push @fields, $entry->class;

    Moose::Util::TypeConstraints::match_on_type $data => (
        HashRef => sub {
            push @headings, keys %$data;
            for my $field ( values %$data ) {
                Moose::Util::TypeConstraints::match_on_type $field => (
                    'KiokuDB::Entry' => sub {
                        push @fields, $field->data;
                }, 
                =>  sub { push @fields, $field } );
            }
        },
        'KiokuDB::Entry' => sub { warn 'oh boi'; },
        Str => sub {
            push @fields, $data;
        },
        => sub { warn 'foobar!' }
    );

    $self->combine( @headings );
    $row = $self->string unless defined $self->column_names;
    $self->column_names( [ @headings ] );

    $self->combine( @fields );
    $row .= $self->string;

    return $row;
}

sub deserialize {
    my ( $self, $blob ) = @_;
    my $data;
    my @lines = split /\n/, $blob;
    my $header = shift @lines;

    my $status = $self->csv->parse($header);
    my @headings = $self->csv->fields;

    for my $line (@lines) {
        $status = $self->csv->parse($line);
        my @fields = $self->csv->fields;
        $data->{$headings[$_]} = $fields[$_] for (0..$#headings);
    }

    my $class = delete $data->{class};

    return KiokuDB::Entry->new( class => $class, data => $data );
}

sub serialize_to_stream {
    my ( $self, $fh, $entry ) = @_;
    $fh->print( $self->serialize($entry) );
    #$self->print( $fh, $entry );
}

=cut
has _deserialize_buffer => (
    isa => "ScalarRef",
    is  => "ro",
    default => sub { my $x = ''; \$x },
);
=cut

sub deserialize_from_stream {
    my ( $self, $fh ) = @_;

    local $_;
    local $/ = "\n";

    return;

=cut
    my $buf = $self->_deserialize_buffer;

    while ( <$fh> ) {
        if ( length($$buf) ) {
            my @data = $self->deserialize($$buf);
            $$buf = $_;
            return @data;
        } else {
            $$buf .= $_;
        }
    }

    if ( length $$buf ) {
        my @data = $self->deserialize($$buf);
        $$buf = '';
        return @data;
    } else {
        return;
    }
=cut
}

1;

__END__

=pod

=head1 NAME

KiokuDB::Backend::Serialize::CSV - L<Text::CSV> based serialization of
L<KiokuDB::Entry> objects.

=head1 SYNOPSIS

    package MyBackend;
    use Moose;

    with qw(KiokuDB::Backend::Serialize::CSV);

=head1 DESCRIPTION

L<KiokuDB::Backend::Serialize::Delegate> is preferred to using this directly.

=head1 METHODS

=over 4

=item serialize $entry

=item deserialize $str

=item serialize_to_stream $fh, $entry

Serializes the entry and prints to the file handle.

=item deserialize_from_stream $fh

Reads until a CSV document boundry is reached, and then deserializes the
current buffer.

=back
