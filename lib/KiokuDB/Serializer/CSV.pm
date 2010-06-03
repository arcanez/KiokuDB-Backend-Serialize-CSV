package KiokuDB::Serializer::CSV;
use Moose;
use namespace::clean -except => 'meta';

with qw(
    KiokuDB::Serializer
    KiokuDB::Backend::Serialize::CSV
);

sub file_extension { "csv" }

__PACKAGE__->meta->make_immutable;

1;

__END__
