package Apache::Language::SW;

#------------------------------------------------------------
#   SmartWorker - HBE Software, Montreal, Canada
#    for information contact smartworker@hbe.ca
#------------------------------------------------------------
# Apache::Language::SW
#  LanguageHandler for SW::App framework
#------------------------------------------------------------
#  CVS ID tag...
# $Id: perl_template.pl,v 1.5 1999/09/01 01:26:46 krapht Exp $
#------------------------------------------------------------

use strict;
use Apache::Language::Constants;
use I18N::LangTags qw(is_language_tag similarity_language_tag same_language_tag);
use vars qw($VERSION);

$VERSION = '0.01';

#no possiblility to modify this Language Storage for now, so it's never modified
#could tweak this to get re-init on demand.
sub modified {return undef;}

sub fetch {
    my ($class, $data, $cfg, $key, $lang) = @_;	
    #are we asked for a specific language?
    return $cfg->{DATA}{STRING_TABLE}{$key}{$lang} if $lang;  
   
    #let's get at the $self of the caller
    #my @args = @{$data->extra_args};
    #my $itself = $args[0];
    
    #first check if there is a pick using $self stuff
    my $variant = what_lang($cfg, keys % {$cfg->{DATA}{STRING_TABLE}{$key}});
    
    #and if not, resort to Apache::Language std behaviour (HTTP Accept-Language: field)
    $variant ||= $data->best_lang(keys % {$cfg->{DATA}{STRING_TABLE}{$key}});
    
    #if there is a match at this point, return it. 
    return $cfg->{DATA}{STRING_TABLE}{$key}{$variant} if $variant;
    
    #let Apache::Language deal with this error correctly.
    return undef;     
}

sub firstkey {
    my ($class, $data, $cfg) = @_;
    my $a = keys %{$cfg->{DATA}{STRING_TABLE}};
    return each %{$cfg->{DATA}{STRING_TABLE}};
    }

sub nextkey {
    my ($class, $data, $cfg, $lastkey) = @_;
    return each %{$cfg->{DATA}{STRING_TABLE}};
    }

sub initialize {
            my ($self, $data, $cfg) = @_;
            if(not defined $cfg->{DATA})
               {
                  my $pkg = $data->package;
                  warn "Language:: Initializing $pkg";
                  my $lang_pkg = "$pkg" . "::Text";

                  eval "use $lang_pkg";
                  if ($@)
                     {
                     warning("Couldn't compile $lang_pkg because: $@",0);
                     return L_DECLINED;
                     }
                 $cfg->{DATA} = new $lang_pkg;
               }
               my @args = @{$data->extra_args};
               my $itself = $args[0];
               $cfg->{Wanted_Languages} = wanted_languages($itself);
    
        return L_OK;
}

sub wanted_languages {
   my $itself = shift;
   my $cfg = shift;
   my $i=0;
   my %langh;
   my @language_list;
   warn "Wanted_languages called";
   #this merges the potentially defined Lang attributes both as HTTP Data and Session Data
   foreach my $lang ((split /,/, $itself->getDataValue("Lang")), (split /,/, $itself->getSessionValue("Lang")))
      {
      $langh{$lang} ||= $i--;
      }
   @language_list = sort {$langh{$b} <=> $langh{$a}} keys %langh;
   
   unshift @language_list, @ { $cfg->{LanguageForced}} if defined $cfg->{LanguageForced};
   
return \@language_list;
}

#given an ordered list of knowns languages, returns the best language 
#choice according to the client request
#Called mostly by LanguageHandlers to figure out what language to pick
sub what_lang {
    my ($cfg,@offered) = @_;
    my ($result, $language);
    
    foreach my $want (@{$cfg->{Wanted_Languages}}) {
    #foreach my $want (@{wanted_languages($itself,$cfg)}) {
        foreach my $offer (@offered) {         
            my $similarity = similarity_language_tag($offer, $want);
            if ($similarity){
                return $offer if same_language_tag($offer, $want);
                }
            if ($similarity > $result){
                $result = $similarity;
                $language = $offer;
                }
        }
    }
    return $language;
}
1;
__END__

=head1 NAME

SW::Something::MyModule - one line description of the module 

=head1 SYNOPSIS

   Give a simple example of the module's use

=head1 DESCRIPTION



=head1 METHODS

  new -  Creates a new instance
  some_other_function - ([param_name],value) -  detailed description of the use each function

=head1 PARAMETERS

	# well known parameters for this object, normally passed into the contruction as a hash, 
	# or gotten and set using the getValue() and setValue() calls.

  text - 
  image - 

=head1 AUTHOR

Scott Wilson
HBE	scott@hbe.ca
Jan 12/99

=head1 REVISION HISTORY

  $Log: perl_template.pl,v $
  Revision 1.5  1999/09/01 01:26:46  krapht
  Hahahahha, removed this %#*(!&()*$& autoloader shit!

  Revision 1.4  1999/08/17 05:22:34  scott
  changed comments

  Revision 1.3  1999/07/14 21:46:03  fhurtubi
  *** empty log message ***


  Revision 1.2  1999/06/18 15:27:18  scott
  Work on User is for some changes to the database layout ....

  Master and Registry are for the new debugging


=head1 SEE ALSO

perl(1).

=cut
