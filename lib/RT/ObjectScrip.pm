use strict;
use warnings;

package RT::ObjectScrip;
use base 'RT::Record::ApplyAndSort';

use RT::Scrip;
use RT::ObjectScrips;

=head1 NAME

RT::ObjectScrip - record representing application of a scrip to a queue

=head1 DESCRIPTION

This record is created if you want to apply a scrip to a queue or globally.

Inherits methods from L<RT::Record::ApplyAndSort>.

For most operations it's better to use methods in L<RT::Scrip>.

=head1 METHODS

=head2 Table

Returns table name for records of this class.

=cut

sub Table {'ObjectScrips'}

=head2 ObjectCollectionClass

Returns class name of collection of records scrips can be applied to.
Now it's only L<RT::Queue>, so 'RT::Queues' is returned.

=cut

sub ObjectCollectionClass {'RT::Queues'}

=head2 Create

Creates a record, e.g. applies scrip to a queue or globally.

It's better to use L<RT::Scrip/AddToObject> method instead.

Takes:

=over 4

=item Scrip

Scrip object or id.

=item Stage

Stage of the scrip. The same scrip can be run in different stages.

=item ObjectId

Id or an object this scrip should be applied to. For now it's a queue.
Use 0 to mean globally.

=item Disabled

Boolean indicator whether this new application is active or not. For now
all applications of the same Scrip should be either disabled or active.

=item Created, Creator, LastUpdated, LastUpdatedBy

Generated automatically from CurrentUser and the current time, but can be
overriden.

=back

=cut

sub Create {
    my $self = shift;
    my %args = (@_);
    $args{'Stage'} ||= 'TransactionCreate'; #XXX: why don't we turn undef into default?
    return $self->SUPER::Create(
        map { $_ => $args{ $_ } } qw(
            Scrip Stage ObjectId
            SortOrder Disabled
            Created Creator
            LastUpdated LastUpdatedBy
        )
    );
}

=head2 ScripObj

Returns the Scrip Object which has the id returned by Scrip

=cut

sub ScripObj {
    my $self = shift;
    my $id = shift || $self->Scrip;
    my $obj = RT::Scrip->new( $self->CurrentUser );
    $obj->Load( $id );
    return $obj;
}

=head2 Neighbors

Stage splits scrips into neighborhoods. See L<RT::Record::ApplyAndSort/Neighbors and Siblings>.

=cut

sub Neighbors {
    my $self = shift;
    my %args = @_;

    my $res = $self->CollectionClass->new( $self->CurrentUser );
    $res->Limit( FIELD => 'Stage', VALUE => $args{'Stage'} || $self->Stage );
    return $res;
}

=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 Scrip

Returns the current value of Scrip.
(In the database, Scrip is stored as int(11).)



=head2 SetScrip VALUE


Set Scrip to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Scrip will be stored as a int(11).)

=head2 Stage

Returns the current value of Stage.
(In the database, Stage is stored as varchar(32).)

=head2 SetStage VALUE

Set Stage to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Stage will be stored as a varchar(32).)

=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut


=head2 SortOrder

Returns the current value of SortOrder.
(In the database, SortOrder is stored as int(11).)



=head2 SetSortOrder VALUE


Set SortOrder to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SortOrder will be stored as a int(11).)


=cut


=head2 Creator

Returns the current value of Creator.
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created.
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy.
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated.
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {

        id =>
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Scrip =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Stage =>
		{read => 1, write => 1, sql_type => 12, length => 32,  is_blob => 0,  is_numeric => 0,  type => 'varchar(32)', default => 'TransactionCreate'},
        ObjectId =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        SortOrder =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Disabled => 
        {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},
        Creator =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

RT::Base->_ImportOverlays();

1;