use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Tk::LineNumberText',
    'VERSION_FROM'	=> 'LineNumberText.pm', # finds $VERSION
    'PREREQ_PM'		=> {},
    'dist'              => {COMPRESS => 'gzip', SUFFIX => 'gz'},
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'LineNumberText.pm', # retrieve abstract from module
       AUTHOR     => 'Jack Dunnigan<dunniganj@cpan.org>') : ()),
);
