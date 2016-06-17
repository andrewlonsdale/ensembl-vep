# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Test::More;
use Test::Exception;
use FindBin qw($Bin);

use lib $Bin;
use VEPTestingConfig;
my $test_cfg = VEPTestingConfig->new();

## BASIC TESTS
##############

# use test
use_ok('Bio::EnsEMBL::VEP::AnnotationSource::Database::RegFeat');



## DATABASE TESTS
#################

SKIP: {
  my $db_cfg = $test_cfg->db_cfg;
  my $can_use_db = $db_cfg && scalar keys %$db_cfg;

  ## REMEMBER TO UPDATE THIS SKIP NUMBER IF YOU ADD MORE TESTS!!!!
  skip 'No local database configured', 31 unless $can_use_db;

  my $multi;

  if($can_use_db) {
    eval q{
      use Bio::EnsEMBL::Test::TestUtils;
      use Bio::EnsEMBL::Test::MultiTestDB;
      1;
    };

    $multi = Bio::EnsEMBL::Test::MultiTestDB->new('homo_vepiens');
  }

  # need to get a config object for further tests
  use_ok('Bio::EnsEMBL::VEP::Config');

  my $cfg = Bio::EnsEMBL::VEP::Config->new({
    %$db_cfg,
    database => 1,
    offline => 0,
    species => 'homo_vepiens',
    regulatory => 1,
  });
  ok($cfg, 'get new config object');
  
  my $as = Bio::EnsEMBL::VEP::AnnotationSource::Database::RegFeat->new({
    config => $cfg
  });

  ok($as, 'new is defined');

  is(ref($as), 'Bio::EnsEMBL::VEP::AnnotationSource::Database::RegFeat', 'check class');

  my $features;


  ## METHODS
  ##########

  is_deeply(
    $as->info,
    {
      'regbuild' => '13.0'
    },
    'info'
  );

  is_deeply(
    $as->get_available_cell_types,
    [
      'A549',
      'CD14+CD16-_monocyte_(CB)',
      'CD14+CD16-_monocyte_(VB)',
      'CD4+_ab_T_cell_(VB)',
      'CD8+_ab_T_cell_(CB)',
      'CM_CD4+_ab_T_cell_(VB)',
      'DND-41',
      'EPC_(VB)',
      'GM12878',
      'H1ESC',
      'HMEC',
      'HSMM',
      'HSMMtube',
      'HUVEC',
      'HUVEC_prol_(CB)',
      'HeLa-S3',
      'HepG2',
      'IMR90',
      'K562',
      'M0_macrophage_(CB)',
      'M0_macrophage_(VB)',
      'M1_macrophage_(CB)',
      'M1_macrophage_(VB)',
      'M2_macrophage_(CB)',
      'M2_macrophage_(VB)',
      'MSC_(VB)',
      'Monocytes-CD14+',
      'NH-A',
      'NHDF-Ad',
      'NHEK',
      'NHLF',
      'Osteobl',
      'eosinophil_(VB)',
      'erythroblast_(CB)',
      'naive_B_cell_(VB)',
      'neutro_myelocyte_(BM)',
      'neutrophil_(CB)',
      'neutrophil_(VB)'
    ],
    'get_available_cell_types - empty'
  );

  $as->{cell_type} = ['HUVEC'];
  ok($as->check_cell_types, 'check_cell_types');

  $as->{cell_type} = ['JUVEC'];
  throws_ok {$as->check_cell_types} qr/Cell type .* unavailable/, 'check_cell_types - fail';

  $features = $as->get_features_by_regions_uncached([[21, 511]]);

  is(ref($features), 'ARRAY', 'get_features_by_regions_uncached ref 1');
  is(scalar @$features, 13, 'get_features_by_regions_uncached count');
  is(ref($features->[0]), 'Bio::EnsEMBL::Funcgen::RegulatoryFeature', 'get_features_by_regions_uncached ref 2');
  is($features->[0]->stable_id, 'ENSR00001963185', 'get_features_by_regions_uncached stable_id');

  is_deeply(
    [sort keys %{{map {ref($_) => 1} @$features}}],
    ['Bio::EnsEMBL::Funcgen::MotifFeature', 'Bio::EnsEMBL::Funcgen::RegulatoryFeature'],
    'get_features_by_regions_uncached feature types'
  );

  # now we should be able to retrieve the same from memory
  $features = $as->get_features_by_regions_cached([[21, 511]]);
  is(ref($features), 'ARRAY', 'get_features_by_regions_cached ref 1');
  is(ref($features->[0]), 'Bio::EnsEMBL::Funcgen::RegulatoryFeature', 'get_features_by_regions_cached ref 2');
  is($features->[0]->stable_id, 'ENSR00001963185', 'get_features_by_regions_cached stable_id');

  $as->clean_cache();
  is_deeply($as->cache, {}, 'clean_cache');



  ## TESTS WITH AN INPUT BUFFER
  #############################

  $cfg = Bio::EnsEMBL::VEP::Config->new({
    %$db_cfg,
    database => 1,
    offline => 0,
    species => 'homo_vepiens',
    regulatory => 1,
  });
  
  $as = Bio::EnsEMBL::VEP::AnnotationSource::Database::RegFeat->new({
    config => $cfg
  });


  use_ok('Bio::EnsEMBL::VEP::Parser::VCF');
  my $p = Bio::EnsEMBL::VEP::Parser::VCF->new({config => $cfg, file => $test_cfg->{test_vcf}});
  ok($p, 'get parser object');

  use_ok('Bio::EnsEMBL::VEP::InputBuffer');
  my $ib = Bio::EnsEMBL::VEP::InputBuffer->new({config => $cfg, parser => $p});
  is(ref($ib), 'Bio::EnsEMBL::VEP::InputBuffer', 'check class');

  is(ref($ib->next()), 'ARRAY', 'check buffer next');

  is_deeply(
    $as->get_all_regions_by_InputBuffer($ib),
    [
      [
        '21',
        511
      ],
      [
        '21',
        512
      ],
      [
        '21',
        513
      ],
      [
        '21',
        514
      ],
      [
        '21',
        515
      ],
      [
        '21',
        517
      ],
      [
        '21',
        518
      ],
      [
        '21',
        519
      ]
    ],
    'get_all_regions_by_InputBuffer'
  );

  $features = $as->get_all_features_by_InputBuffer($ib);
  is(ref($features), 'ARRAY', 'get_all_features_by_InputBuffer ref 1');
  is(ref($features->[0]), 'Bio::EnsEMBL::Funcgen::RegulatoryFeature', 'get_all_features_by_InputBuffer ref 2');
  is(ref($features->[-1]), 'Bio::EnsEMBL::Funcgen::RegulatoryFeature', 'get_all_features_by_InputBuffer ref 3');
  is($features->[0]->stable_id, 'ENSR00001963192', 'get_all_features_by_InputBuffer stable_id');
  is(scalar @$features, 93, 'get_all_features_by_InputBuffer count');

  # do it again to get them from memory
  $features = $as->get_all_features_by_InputBuffer($ib);
  is($features->[0]->stable_id, 'ENSR00001963192', 'get_all_features_by_InputBuffer again');

  $ib->next();
  is_deeply($as->get_all_features_by_InputBuffer($ib), [], 'get_all_features_by_InputBuffer on empty buffer');

  # reset
  $p = Bio::EnsEMBL::VEP::Parser::VCF->new({config => $cfg, file => $test_cfg->{test_vcf}});
  $ib = Bio::EnsEMBL::VEP::InputBuffer->new({config => $cfg, parser => $p});
  $ib->next();

  $as->annotate_InputBuffer($ib);
  my $vf = $ib->buffer->[0];
  my $rfvs = $vf->get_all_RegulatoryFeatureVariations;

  is(scalar @$rfvs, 1, 'annotate_InputBuffer - get_all_RegulatoryFeatureVariations count');

  $vf->_finish_annotation;
  is($vf->display_consequence, 'regulatory_region_variant', 'annotate_InputBuffer - display_consequence');


  1;
}

# done
done_testing();
