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
use vars qw($VERSION %LANG_HASH);
$VERSION = '0.01';

use Apache::Language::Constants;
use I18N::LangTags qw(is_language_tag similarity_language_tag same_language_tag);

#Apache::Language API required methods.

sub fetch {
    my ($class, $data, $cfg, $key, $lang) = @_;	
    
    #are we asked for a specific language?
    return $cfg->{DATA}{STRING_TABLE}{$key}{$lang} if $lang;  
   
    #first check if there is a pick using $self stuff
    my $variant = what_lang($cfg, keys % {$cfg->{DATA}{STRING_TABLE}{$key}});
    
    #and if not, resort to Apache::Language std behaviour (HTTP Accept-Language: field)
    $variant ||= $data->best_lang(keys % {$cfg->{DATA}{STRING_TABLE}{$key}});
    
    #if there is a match at this point, return it. 
    return $cfg->{DATA}{STRING_TABLE}{$key}{$variant} if $variant;
    
    #and if not, let Apache::Language deal with this error elegantly.
    return undef;     
}

#Here we set-up things for a whole request and a whole server process
sub initialize {
            my ($self, $data, $cfg) = @_;
            #did we already decline on this combination ?
            return L_DECLINED if (exists $cfg->{no_good}); 

            if(not exists $cfg->{DATA})
               {  #this is done once per server process.
                  my $pkg = $data->package;
                  warning("Language:: Initializing $pkg",3);
                  #build the correct package name
                  my $lang_pkg = "$pkg" . "::Text";

                  eval "use $lang_pkg";
                  if ($@)
                     {
                     warning("Couldn't compile $lang_pkg because: $@",1) unless ($@ =~ /Can\'t locate/);
                     $cfg->{no_good} = "";   #make sure we remember this fails
                     return L_DECLINED;
                     }
                 #stash an instance of the package for later use.
                 $cfg->{DATA} = new $lang_pkg;
               }
               
               #This is done once per request (It will not change in the same page)
               $cfg->{Wanted_Languages} = wanted_languages(${$data->extra_args}[0]);
    
return L_OK;
}

#We need to be re-initialized on each request, so fake on modification-since check
sub modified {return 1;}

#This is supposed to work, but untested. So be carefull about endless loops...
sub firstkey {
    my ($class, $data, $cfg) = @_;
    my $a = keys %{$cfg->{DATA}{STRING_TABLE}};
    return each %{$cfg->{DATA}{STRING_TABLE}};
    }
#same thing here
sub nextkey {
    my ($class, $data, $cfg, $lastkey) = @_;
    return each %{$cfg->{DATA}{STRING_TABLE}};
    }

#Apache::Language required API ends here.
#------------------------------------------

#Apache::Language surplus function
#--------------------------------------------------------------------------------
#  getLanguagePicker
#
#     Function that returns a language picking panel.  It should
#      be called like this :
#           $Panel->addElement(x,y,$self->{Language}->getLanguagePicker());
#  
#     NOTE :   Since this can be added in a Form Panel or an HTML Panel, it's
#              important to call it with a true argument when in non-Form context        
#--------------------------------------------------------------------------------
sub getLanguagePicker {
   my $self = shift;
   my $data = shift;
   my $cfg = shift;
   my $arg = shift;
   
   #this is to get at the first argument we passed the new method
   my $itself = ${$data->extra_args}[0];
   
   #figure out what's the language being currently served
   my $current_lang = ${$cfg->{Wanted_Languages}}[0] || ${$data->lang()}[0];
   
   #create 2 lists, of 2-letters languages codes and their expanded versions
   my @variant;
   my @variant_list; 
   foreach my $variant ( sort { $LANG_HASH{$a} cmp $LANG_HASH{$b} } @{$cfg->{DATA}{VARIANT_LIST}} )
      {
      push @variant, $variant;
      push @variant_list, $LANG_HASH{$variant} || $variant;
      }
   
   #find out what type of panel we need to create
   my $panel_type = $arg ? "SW::Panel::FormPanel" :"SW::Panel::HTMLPanel" ;

   
   my $LangPanel = new $panel_type($itself, {
                           -bgColor    => "000000",
                           -name       => "langPanel",
                           -align		=> "right",
                           -height		=> "1% ",
                           });
   #Add a pull-down list
   $LangPanel->addElement(0,0, new SW::GUIElement::SelectBox($itself, {
                           -name       => 'Lang',
                           -options    => \@variant_list,
                           -values     => \@variant,
                           -selected   => $current_lang,
                           -width      => "1% ",
                           }));
                     
   #And the Go button                  
   $LangPanel->addElement(1,0, new SW::GUIElement::Button($itself, {
                           -text   	   => "GO",
                           -width		=> "1% ",
                           }));
                   
#throw back the resulting panel                
return $LangPanel;
}

sub wanted_languages {
   my $itself = shift;
   my $cfg = shift;
   
   my %langh;
   my @language_list;
   
   #this merges the potentially defined Lang attributes both as HTTP Data and Session Data
   #we should hook into the user preferences in here.
   #and the merging could be a bit better
   my $i=0;
   foreach my $lang ((split /,/, $itself->getDataValue("Lang")), (split /,/, $itself->getSessionValue("Lang")))
      {
      $langh{$lang} ||= $i--;
      }
   #sort them by preference
   @language_list = sort {$langh{$b} <=> $langh{$a}} keys %langh;
   #add any forced languages before everything else
   unshift @language_list, @ { $cfg->{LanguageForced}} if defined $cfg->{LanguageForced};
   
return \@language_list;
}

#given an ordered list of knowns languages, returns the best language 
#choice according to the client preferences (Copied from Apache::Language)
sub what_lang {
    my ($cfg,@offered) = @_;
    my ($result, $language);
    
    foreach my $want (@{$cfg->{Wanted_Languages}}) {
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

#Does not belong in here, but where ?
%LANG_HASH = ( #This should be way bigger and in another file even.
   'en'     => "English",
   'fr'     => "Fran&ccedil;ais",
   'es'     => "Espa&ntilde;ol",
   'de'     => "Deutsh",
   );

1;

__END__

=head1 NAME

Apache::Language::SW - LanguageHandler for SmartWorker Applications

=head1 SYNOPSIS

   sub new
   {
      my $classname = shift;
	   my $self = $classname->SUPER::new(@_);
      $self->{Language} = new Apache::Language($self);
      [...]
   }
   
      [...]
      -text => $self->{Language}{"keyName1"},
      [...]
      $Panel->addElement(x,y,$self->{Language}->getLanguagePicker());
      [...]
      

=head1 DESCRIPTION

This is the new way to handle Language in SW::Applications.  The interface is a
tied hash, so you can use the object returned by Apache::Language like any other
hash reference.  

There are also a few function calls you can make on it, like the getLanguagePicker() sub
that returns a Language picker panel ready to insert in your application.

The only restriction with this module is that it uses the 'Lang' key to find
wanted languages.  So it sets it in the Session/Data stuff.  So don't do this:

  $self->{Lang} = "I love perl";
  
But you can look at it if you want to know what language are requested by the user,
but I advise against it.

=head1 METHODS

  getLanguagePicker - Returns a panel with a correct language picker for the current user. 
  
  Arguments : call it with a true argument when outside form context.

=head1 AUTHOR

Philippe M. Chiasson
HBE	gozer@hbe.ca
Sept  9/99

=head1 REVISION HISTORY

  $Log$

=head1 SEE ALSO

perl(1).

Apache::Language(3).

Apache::Language::*(3).

=cut
