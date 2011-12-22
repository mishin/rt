# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use strict;
use warnings;

package RT::Record::ApplyAndSort;
use base 'RT::Record';

sub CollectionClass {
    return (ref($_[0]) || $_[0]).'s';
}

sub ObjectCollectionClass { die "should be subclassed" }

sub TargetField {
    my $class = ref($_[0]) || $_[0];
    $class =~ s/.*::Object// or return undef;
    return $class;
}

sub Create {
    my $self = shift;
    my %args = (
        ObjectId    => 0,
        SortOrder   => undef,
        @_
    );

    my $tfield = $self->TargetField;

    my $target = $self->TargetObj( $args{ $tfield } );
    unless ( $target->id ) {
        $RT::Logger->error("Couldn't load ". ref($target) ." '$args{'Scrip'}'");
        return 0;
    }

    my $exist = $self->new($self->CurrentUser);
    $exist->LoadByCols( ObjectId => $args{'ObjectId'}, $tfield => $target->id );
    if ( $exist->id ) {
        $self->Load( $exist->id );
        return $self->id;
    }

    unless ( defined $args{'SortOrder'} ) {
        $args{'SortOrder'} = $self->NextSortOrder(
            $tfield  => $target,
            ObjectId => $args{'ObjectId'},
        );
    }
    $args{'Disabled'} ||= 0;

    return $self->SUPER::Create(
        %args,
        $tfield   => $target->id,
    );
}

sub Apply {
    my $self = shift;
    my %args = (@_);

    my $field = $self->TargetField;

    my $tid = $args{ $field };
    $tid = $tid->id if ref $tid;
    $tid ||= $self->TargetObj->id;

    my $oid = $args{'ObjectId'};
    $oid = $oid->id if ref $oid;
    $oid ||= 0;

    if ( $self->IsApplied( $tid => $oid ) ) {
        return ( 0, $self->loc("Is already applied to the object") );
    }

    if ( $oid ) {
        # applying locally
        return (0, $self->loc("Couldn't apply as it's global already") )
            if $self->IsApplied( $tid => 0 );
    }
    else {
        $self->DeleteAll( $field => $tid );
    }

    return $self->Create(
        $field => $tid, ObjectId => $oid,
    );
}

sub IsApplied {
    my $self = shift;
    my ($tid, $oid) = @_;
    my $record = $self->new( $self->CurrentUser );
    $record->LoadByCols( $self->TargetField => $tid, ObjectId => $oid );
    return $record->id;
}

=head1 AppliedTo

Returns collection with objects this custom field is applied to.
Class of the collection depends on L</LookupType>.
See all L</NotAppliedTo> .

Doesn't takes into account if object is applied globally.

=cut

sub AppliedTo {
    my $self = shift;

    my ($res, $alias) = $self->_AppliedTo( @_ );
    return $res unless $res;

    $res->Limit(
        ALIAS     => $alias,
        FIELD     => 'id',
        OPERATOR  => 'IS NOT',
        VALUE     => 'NULL',
    );

    return $res;
}

=head1 NotAppliedTo

Returns collection with objects this custom field is not applied to.
Class of the collection depends on L</LookupType>.
See all L</AppliedTo> .

Doesn't takes into account if object is applied globally.

=cut

sub NotAppliedTo {
    my $self = shift;

    my ($res, $alias) = $self->_AppliedTo( @_ );
    return $res unless $res;

    $res->Limit(
        ALIAS     => $alias,
        FIELD     => 'id',
        OPERATOR  => 'IS',
        VALUE     => 'NULL',
    );

    return $res;
}

sub _AppliedTo {
    my $self = shift;
    my %args = (@_);

    my $field = $self->TargetField;
    my $target = $args{ $field } || $self->TargetObj;

    my ($class) = $self->ObjectCollectionClass( $field => $target );
    return undef unless $class;

    my $res = $class->new( $self->CurrentUser );

    # If target applied to a Group, only display user-defined groups
    $res->LimitToUserDefinedGroups if $class eq 'RT::Groups';

    $res->OrderBy( FIELD => 'Name' );
    my $alias = $res->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => $self->Table,
        FIELD2 => 'ObjectId',
    );
    $res->Limit(
        LEFTJOIN => $alias,
        ALIAS    => $alias,
        FIELD    => $field,
        VALUE    => $target->id,
    );
    return ($res, $alias);
}

sub Delete {
    my $self = shift;

    my $siblings = $self->Neighbors;
    $siblings->LimitToObjectId( $self->ObjectId );
    $siblings->Limit( FIELD => 'SortOrder', OPERATOR => '>', VALUE => $self->SortOrder );

    # Move everything below us up
    my $sort_order = $self->SortOrder;
    while (my $record = $siblings->Next) {
        $record->SetSortOrder($record->SortOrder - 1);
    }

    $self->SUPER::Delete;
}

sub DeleteAll {
    my $self = shift;
    my %args = (@_);

    my $field = $self->TargetField;

    my $id = $args{ $field };
    $id = $id->id if ref $id;
    $id ||= $self->TargetObj->id;

    my $list = $self->CollectionClass->new( $self->CurrentUser );
    $list->Limit( FIELD => $field, VALUE => $id );
    $_->Delete foreach @{ $list->ItemsArrayRef };
}

sub SetDisabledOnAll {
    my $self = shift;
    my %args = (@_);

    my $field = $self->TargetField;

    my $id = $args{ $field };
    $id = $id->id if ref $id;
    $id ||= $self->TargetObj->id;

    my $list = $self->CollectionClass->new( $self->CurrentUser );
    $list->Limit( FIELD => $field, VALUE => $id );
    foreach ( @{ $list->ItemsArrayRef } ) {
        my ($status, $msg) = $_->SetDisabled( $args{Value} || 0 );
        return ($status, $msg) unless $status;
    }
    return (1, $self->loc("Disabled all applications") );
}

=head2 Sorting scrips applications

scrips sorted on multiple layers. First of all custom
fields with different lookup type are sorted independently. All
global scrips have fixed order for all objects, but you
can insert object specific scrips between them. Object
specific scrips can be applied to several objects and
be on different place. For example you have GCF1, GCF2, LCF1,
LCF2 and LCF3 that applies to tickets. You can place GCF2
above GCF1, but they will be in the same order in all queues.
However, LCF1 and other local can be placed at any place
for particular queue: above global, between them or below.

=head3 MoveUp

Moves scrip up. See </Sorting scrips applications>.

=cut

sub MoveUp {
    my $self = shift;

    my $siblings = $self->Siblings;
    $siblings->Limit( FIELD => 'SortOrder', OPERATOR => '<', VALUE => $self->SortOrder );
    $siblings->OrderByCols( { FIELD => 'SortOrder', ORDER => 'DESC' } );

    my @above = ($siblings->Next, $siblings->Next);
    unless ($above[0]) {
        return (0, "Can not move up. It's already at the top");
    }

    my $new_sort_order;
    if ( $above[0]->ObjectId == $self->ObjectId ) {
        $new_sort_order = $above[0]->SortOrder;
        my ($status, $msg) = $above[0]->SetSortOrder( $self->SortOrder );
        unless ( $status ) {
            return (0, "Couldn't move scrip");
        }
    }
    elsif ( $above[1] && $above[0]->SortOrder == $above[1]->SortOrder + 1 ) {
        my $move_siblings = $self->Neighbors;
        $move_siblings->Limit(
            FIELD => 'SortOrder',
            OPERATOR => '>=',
            VALUE => $above[0]->SortOrder,
        );
        $move_siblings->OrderByCols( { FIELD => 'SortOrder', ORDER => 'DESC' } );
        while ( my $record = $move_siblings->Next ) {
            my ($status, $msg) = $record->SetSortOrder( $record->SortOrder + 1 );
            unless ( $status ) {
                return (0, "Couldn't move scrip");
            }
        }
        $new_sort_order = $above[0]->SortOrder;
    } else {
        $new_sort_order = $above[0]->SortOrder - 1;
    }

    my ($status, $msg) = $self->SetSortOrder( $new_sort_order );
    unless ( $status ) {
        return (0, "Couldn't move scrip");
    }

    return (1,"Moved scrip up");
}

=head3 MoveDown

Moves scrip down. See </Sorting scrips applications>.

=cut

sub MoveDown {
    my $self = shift;

    my $siblings = $self->Siblings;
    $siblings->Limit( FIELD => 'SortOrder', OPERATOR => '>', VALUE => $self->SortOrder );
    $siblings->OrderByCols( { FIELD => 'SortOrder', ORDER => 'ASC' } );

    my @below = ($siblings->Next, $siblings->Next);
    unless ($below[0]) {
        return (0, "Can not move down. It's already at the bottom");
    }

    my $new_sort_order;
    if ( $below[0]->ObjectId == $self->ObjectId ) {
        $new_sort_order = $below[0]->SortOrder;
        my ($status, $msg) = $below[0]->SetSortOrder( $self->SortOrder );
        unless ( $status ) {
            return (0, "Couldn't move scrip");
        }
    }
    elsif ( $below[1] && $below[0]->SortOrder + 1 == $below[1]->SortOrder ) {
        my $move_siblings = $self->Neighbors;
        $move_siblings->Limit(
            FIELD => 'SortOrder',
            OPERATOR => '<=',
            VALUE => $below[0]->SortOrder,
        );
        $move_siblings->OrderByCols( { FIELD => 'SortOrder', ORDER => 'ASC' } );
        while ( my $record = $move_siblings->Next ) {
            my ($status, $msg) = $record->SetSortOrder( $record->SortOrder - 1 );
            unless ( $status ) {
                return (0, "Couldn't move scrip");
            }
        }
        $new_sort_order = $below[0]->SortOrder;
    } else {
        $new_sort_order = $below[0]->SortOrder + 1;
    }

    my ($status, $msg) = $self->SetSortOrder( $new_sort_order );
    unless ( $status ) {
        return (0, "Couldn't move scrip");
    }

    return (1,"Moved scrip down");
}

sub NextSortOrder {
    my $self = shift;
    my $siblings = $self->Siblings( @_ );
    $siblings->OrderBy( FIELD => 'SortOrder', ORDER => 'DESC' );
    return 0 unless my $first = $siblings->First;
    return $first->SortOrder + 1;
}

sub TargetObj {
    my $self = shift;
    my $id   = shift;

    my $method = $self->TargetField .'Obj';
    return $self->$method( $id );
}

sub Neighbors {
    my $self = shift;
    return $self->CollectionClass->new( $self->CurrentUser );
}

sub Siblings {
    my $self = shift;
    my %args = @_;

    my $oid = $args{'ObjectId'};
    $oid = $self->ObjectId unless defined $oid;
    $oid ||= 0;

    my $res = $self->Neighbors( %args );
    $res->LimitToObjectId( $oid );
    $res->LimitToObjectId( 0 ) if $oid;
    return $res;
}

RT::Base->_ImportOverlays();

1;
