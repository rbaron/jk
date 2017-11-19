#use 5.026001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'JK::Editor',
    VERSION_FROM      => 'lib/JK/Editor.pm',
    PREREQ_PM         => {
      'Term::Size'    => 0.207,
      'Term::ReadKey' => 2.37,
    },
    TEST_REQUIRES => {
      'File::Temp' => 0.2304,
    },
    ABSTRACT_FROM     => 'lib/JK/Editor.pm',
    AUTHOR            => 'Raphael Baron <rbaron@local>',
    LICENSE           => 'mit',
);
