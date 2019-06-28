# frozen_string_literal: true

require 'spec_helper'
require 'labware_creators/base'
# require_relative '../../support/shared_tagging_examples'
require_relative 'shared_examples'

RSpec.describe LabwareCreators::ConcentrationBinnedPlate do
  it_behaves_like 'it only allows creation from plates'
  it_behaves_like 'it has no custom page'

  has_a_working_api

  let(:parent_uuid) { 'example-plate-uuid' }
  let(:plate_size) { 96 }

  let(:well_a1) do
    create(:v2_well,
           position: { 'name' => 'A1' },
           qc_results: create_list(:qc_result_concentration, 1, value: 1.5))
  end
  let(:well_b1) do
    create(:v2_well,
           position: { 'name' => 'B1' },
           qc_results: create_list(:qc_result_concentration, 1, value: 56.0))
  end
  let(:well_c1) do
    create(:v2_well,
           position: { 'name' => 'C1' },
           qc_results: create_list(:qc_result_concentration, 1, value: 3.5))
  end
  let(:well_d1) do
    create(:v2_well,
           position: { 'name' => 'D1' },
           qc_results: create_list(:qc_result_concentration, 1, value: 1.8))
  end

  let(:parent_plate) do
    create :v2_plate,
           uuid: parent_uuid,
           barcode_number: '2',
           size: plate_size,
           wells: [well_a1, well_b1, well_c1, well_d1],
           outer_requests: requests
  end

  let(:child_plate) do
    create :v2_plate,
           uuid: 'child-uuid',
           barcode_number: '3',
           size: plate_size,
           outer_requests: requests
  end

  let(:requests) { Array.new(4) { |i| create :library_request, state: 'started', uuid: "request-#{i}" } }

  let(:child_purpose_uuid) { 'child-purpose' }
  let(:child_purpose_name) { 'Child Purpose' }

  let(:user_uuid) { 'user-uuid' }

  before do
    create :concentration_binning_purpose_config, uuid: child_purpose_uuid, name: child_purpose_name
    stub_v2_plate(child_plate, stub_search: false)
    stub_v2_plate(parent_plate, stub_search: false, custom_includes: 'wells.aliquots,wells.qc_results')
  end

  let(:form_attributes) do
    {
      purpose_uuid: child_purpose_uuid,
      parent_uuid: parent_uuid,
      user_uuid: user_uuid
    }
  end

  subject do
    LabwareCreators::ConcentrationBinnedPlate.new(api, form_attributes)
  end

  context 'on new' do
    it 'can be created' do
      expect(subject).to be_a LabwareCreators::ConcentrationBinnedPlate
    end

    context 'wells missing concentration value' do
      let(:well_e1) do
        create(:v2_well,
               position: { 'name' => 'D1' },
               qc_results: {})
      end

      let(:parent_plate) do
        create :v2_plate,
               uuid: parent_uuid,
               barcode_number: '2',
               size: plate_size,
               wells: [well_a1, well_b1, well_c1, well_d1, well_e1],
               outer_requests: requests
      end

      it 'fails validation' do
        expect(subject).to_not be_valid
      end
    end

    context 'missing binning configuration' do
      before do
        create :concentration_binning_purpose_config, uuid: child_purpose_uuid, name: child_purpose_name, concentration_binning: {}
      end

      it 'fails validation if binning configuration is not present' do
        expect(subject).to_not be_valid
      end
    end

    context 'no bins in binning configuration' do
      before do
        create :concentration_binning_purpose_config,
               uuid: child_purpose_uuid,
               name: child_purpose_name,
               concentration_binning: {
                 source_volume: 10,
                 diluent_volume: 25,
                 bins: []
               }
      end

      it 'fails validation if binning configuration has not specified bins' do
        expect(subject).to_not be_valid
      end
    end
  end

  context 'concentration binning' do
    let(:num_rows) { 8 }
    let(:num_cols) { 12 }

    it 'calculates plate well amounts correctly' do
      expected_amounts = { 'A1' => '15.0', 'B1' => '560.0', 'C1' => '35.0', 'D1' => '18.0' }
      mult_factor = subject.class.source_plate_multiplication_factor(subject.binning_config)

      expect(mult_factor).to eq(10.0)
      expect(subject.class.compute_well_amounts(parent_plate, mult_factor)).to eq(expected_amounts)
    end

    context 'when generating transfers' do
      let(:binning_config_large) do
        {
          'source_volume' => 10,
          'diluent_volume' => 25,
          'bins' => [
            { 'colour' => 1, 'pcr_cycles' => 20, 'max' => 10 },
            { 'colour' => 2, 'pcr_cycles' => 19, 'min' => 10, 'max' => 20 },
            { 'colour' => 3, 'pcr_cycles' => 18, 'min' => 20, 'max' => 30 },
            { 'colour' => 4, 'pcr_cycles' => 17, 'min' => 30, 'max' => 40 },
            { 'colour' => 5, 'pcr_cycles' => 16, 'min' => 40, 'max' => 50 },
            { 'colour' => 6, 'pcr_cycles' => 15, 'min' => 50, 'max' => 60 },
            { 'colour' => 7, 'pcr_cycles' => 14, 'min' => 60, 'max' => 70 },
            { 'colour' => 8, 'pcr_cycles' => 13, 'min' => 70, 'max' => 80 },
            { 'colour' => 9, 'pcr_cycles' => 12, 'min' => 80, 'max' => 90 },
            { 'colour' => 10, 'pcr_cycles' => 11, 'min' => 90, 'max' => 100 },
            { 'colour' => 11, 'pcr_cycles' => 10, 'min' => 100, 'max' => 110 },
            { 'colour' => 12, 'pcr_cycles' => 9, 'min' => 110, 'max' => 120 },
            { 'colour' => 13, 'pcr_cycles' => 8, 'min' => 120 }
          ]
        }
      end

      it 'works for a simple source plate and bin config' do
        well_amounts = { 'A1' => '15.0', 'B1' => '560.0', 'C1' => '35.0', 'D1' => '18.0' }
        expd_transfers = {
          'A1' => { 'dest_locn' => 'A1', 'dest_conc' => '0.429' },
          'B1' => { 'dest_locn' => 'A3', 'dest_conc' => '16.0' },
          'C1' => { 'dest_locn' => 'A2', 'dest_conc' => '1.0' },
          'D1' => { 'dest_locn' => 'B1', 'dest_conc' => '0.514' }
        }

        expect(subject.class.compute_transfers(well_amounts, subject.binning_config, num_rows, num_cols)).to eq(expd_transfers)
      end

      it 'works when all wells fall into the same bin' do
        well_amounts = { 'A1' => '26.0', 'B1' => '26.0', 'C1' => '26.0', 'D1' => '26.0' }
        expd_transfers = {
          'A1' => { 'dest_locn' => 'A1', 'dest_conc' => '0.743' },
          'B1' => { 'dest_locn' => 'B1', 'dest_conc' => '0.743' },
          'C1' => { 'dest_locn' => 'C1', 'dest_conc' => '0.743' },
          'D1' => { 'dest_locn' => 'D1', 'dest_conc' => '0.743' }
        }

        expect(subject.class.compute_transfers(well_amounts, subject.binning_config, num_rows, num_cols)).to eq(expd_transfers)
      end

      it 'works when bins span multiple columns' do
        well_amounts = {
          'A1' => '1.0', 'B1' => '26.0', 'C1' => '501.0', 'D1' => '26.0', 'E1' => '26.0', 'F1' => '26.0',
          'G1' => '26.0', 'H1' => '26.0', 'A2' => '26.0', 'B2' => '26.0', 'C2' => '26.0', 'D2' => '26.0',
          'E2' => '26.0', 'F2' => '26.0', 'G2' => '26.0', 'H2' => '26.0', 'A3' => '26.0', 'B3' => '26.0',
          'C3' => '26.0', 'D3' => '26.0', 'E3' => '26.0', 'F3' => '26.0'
        }
        expd_transfers = {
          'A1' => { 'dest_locn' => 'A1', 'dest_conc' => '0.029' },
          'B1' => { 'dest_locn' => 'A2', 'dest_conc' => '0.743' },
          'C1' => { 'dest_locn' => 'A5', 'dest_conc' => '14.314' },
          'D1' => { 'dest_locn' => 'B2', 'dest_conc' => '0.743' },
          'E1' => { 'dest_locn' => 'C2', 'dest_conc' => '0.743' },
          'F1' => { 'dest_locn' => 'D2', 'dest_conc' => '0.743' },
          'G1' => { 'dest_locn' => 'E2', 'dest_conc' => '0.743' },
          'H1' => { 'dest_locn' => 'F2', 'dest_conc' => '0.743' },
          'A2' => { 'dest_locn' => 'G2', 'dest_conc' => '0.743' },
          'B2' => { 'dest_locn' => 'H2', 'dest_conc' => '0.743' },
          'C2' => { 'dest_locn' => 'A3', 'dest_conc' => '0.743' },
          'D2' => { 'dest_locn' => 'B3', 'dest_conc' => '0.743' },
          'E2' => { 'dest_locn' => 'C3', 'dest_conc' => '0.743' },
          'F2' => { 'dest_locn' => 'D3', 'dest_conc' => '0.743' },
          'G2' => { 'dest_locn' => 'E3', 'dest_conc' => '0.743' },
          'H2' => { 'dest_locn' => 'F3', 'dest_conc' => '0.743' },
          'A3' => { 'dest_locn' => 'G3', 'dest_conc' => '0.743' },
          'B3' => { 'dest_locn' => 'H3', 'dest_conc' => '0.743' },
          'C3' => { 'dest_locn' => 'A4', 'dest_conc' => '0.743' },
          'D3' => { 'dest_locn' => 'B4', 'dest_conc' => '0.743' },
          'E3' => { 'dest_locn' => 'C4', 'dest_conc' => '0.743' },
          'F3' => { 'dest_locn' => 'D4', 'dest_conc' => '0.743' }
        }

        expect(subject.class.compute_transfers(well_amounts, subject.binning_config, num_rows, num_cols)).to eq(expd_transfers)
      end

      # rubocop:disable Metrics/BlockLength
      it 'works when requiring compression due to numbers of wells' do
        well_amounts = {
          'A1' => '1.0', 'B1' => '1.0', 'C1' => '1.0', 'D1' => '1.0', 'E1' => '1.0', 'F1' => '1.0', 'G1' => '1.0', 'H1' => '1.0',
          'A2' => '1.0', 'B2' => '1.0', 'C2' => '1.0', 'D2' => '1.0', 'E2' => '1.0', 'F2' => '1.0', 'G2' => '1.0', 'H2' => '1.0',
          'A3' => '1.0', 'B3' => '1.0', 'C3' => '1.0', 'D3' => '1.0', 'E3' => '1.0', 'F3' => '1.0', 'G3' => '1.0', 'H3' => '1.0',
          'A4' => '1.0', 'B4' => '1.0', 'C4' => '1.0', 'D4' => '1.0', 'E4' => '1.0', 'F4' => '1.0', 'G4' => '1.0', 'H4' => '1.0',
          'A5' => '1.0', 'B5' => '26.0', 'C5' => '26.0', 'D5' => '26.0', 'E5' => '26.0', 'F5' => '26.0', 'G5' => '26.0', 'H5' => '26.0',
          'A6' => '26.0', 'B6' => '26.0', 'C6' => '26.0', 'D6' => '26.0', 'E6' => '26.0', 'F6' => '26.0', 'G6' => '26.0', 'H6' => '26.0',
          'A7' => '26.0', 'B7' => '26.0', 'C7' => '26.0', 'D7' => '26.0', 'E7' => '26.0', 'F7' => '26.0', 'G7' => '26.0', 'H7' => '26.0',
          'A8' => '26.0', 'B8' => '26.0', 'C8' => '26.0', 'D8' => '26.0', 'E8' => '26.0', 'F8' => '26.0', 'G8' => '26.0', 'H8' => '501.0',
          'A9' => '501.0', 'B9' => '501.0', 'C9' => '501.0', 'D9' => '501.0', 'E9' => '501.0', 'F9' => '501.0', 'G9' => '501.0', 'H9' => '501.0',
          'A10' => '501.0', 'B10' => '501.0', 'C10' => '501.0', 'D10' => '501.0', 'E10' => '501.0', 'F10' => '501.0', 'G10' => '501.0', 'H10' => '501.0',
          'A11' => '501.0', 'B11' => '501.0', 'C11' => '501.0', 'D11' => '501.0', 'E11' => '501.0', 'F11' => '501.0', 'G11' => '501.0', 'H11' => '501.0',
          'A12' => '501.0', 'B12' => '501.0', 'C12' => '501.0', 'D12' => '501.0', 'E12' => '501.0', 'F12' => '501.0', 'G12' => '501.0', 'H12' => '501.0'
        }
        expd_transfers = {
          'A1' => { 'dest_locn' => 'A1', 'dest_conc' => '0.029' },
          'B1' => { 'dest_locn' => 'B1', 'dest_conc' => '0.029' },
          'C1' => { 'dest_locn' => 'C1', 'dest_conc' => '0.029' },
          'D1' => { 'dest_locn' => 'D1', 'dest_conc' => '0.029' },
          'E1' => { 'dest_locn' => 'E1', 'dest_conc' => '0.029' },
          'F1' => { 'dest_locn' => 'F1', 'dest_conc' => '0.029' },
          'G1' => { 'dest_locn' => 'G1', 'dest_conc' => '0.029' },
          'H1' => { 'dest_locn' => 'H1', 'dest_conc' => '0.029' },
          'A2' => { 'dest_locn' => 'A2', 'dest_conc' => '0.029' },
          'B2' => { 'dest_locn' => 'B2', 'dest_conc' => '0.029' },
          'C2' => { 'dest_locn' => 'C2', 'dest_conc' => '0.029' },
          'D2' => { 'dest_locn' => 'D2', 'dest_conc' => '0.029' },
          'E2' => { 'dest_locn' => 'E2', 'dest_conc' => '0.029' },
          'F2' => { 'dest_locn' => 'F2', 'dest_conc' => '0.029' },
          'G2' => { 'dest_locn' => 'G2', 'dest_conc' => '0.029' },
          'H2' => { 'dest_locn' => 'H2', 'dest_conc' => '0.029' },
          'A3' => { 'dest_locn' => 'A3', 'dest_conc' => '0.029' },
          'B3' => { 'dest_locn' => 'B3', 'dest_conc' => '0.029' },
          'C3' => { 'dest_locn' => 'C3', 'dest_conc' => '0.029' },
          'D3' => { 'dest_locn' => 'D3', 'dest_conc' => '0.029' },
          'E3' => { 'dest_locn' => 'E3', 'dest_conc' => '0.029' },
          'F3' => { 'dest_locn' => 'F3', 'dest_conc' => '0.029' },
          'G3' => { 'dest_locn' => 'G3', 'dest_conc' => '0.029' },
          'H3' => { 'dest_locn' => 'H3', 'dest_conc' => '0.029' },
          'A4' => { 'dest_locn' => 'A4', 'dest_conc' => '0.029' },
          'B4' => { 'dest_locn' => 'B4', 'dest_conc' => '0.029' },
          'C4' => { 'dest_locn' => 'C4', 'dest_conc' => '0.029' },
          'D4' => { 'dest_locn' => 'D4', 'dest_conc' => '0.029' },
          'E4' => { 'dest_locn' => 'E4', 'dest_conc' => '0.029' },
          'F4' => { 'dest_locn' => 'F4', 'dest_conc' => '0.029' },
          'G4' => { 'dest_locn' => 'G4', 'dest_conc' => '0.029' },
          'H4' => { 'dest_locn' => 'H4', 'dest_conc' => '0.029' },
          'A5' => { 'dest_locn' => 'A5', 'dest_conc' => '0.029' },
          'B5' => { 'dest_locn' => 'B5', 'dest_conc' => '0.743' },
          'C5' => { 'dest_locn' => 'C5', 'dest_conc' => '0.743' },
          'D5' => { 'dest_locn' => 'D5', 'dest_conc' => '0.743' },
          'E5' => { 'dest_locn' => 'E5', 'dest_conc' => '0.743' },
          'F5' => { 'dest_locn' => 'F5', 'dest_conc' => '0.743' },
          'G5' => { 'dest_locn' => 'G5', 'dest_conc' => '0.743' },
          'H5' => { 'dest_locn' => 'H5', 'dest_conc' => '0.743' },
          'A6' => { 'dest_locn' => 'A6', 'dest_conc' => '0.743' },
          'B6' => { 'dest_locn' => 'B6', 'dest_conc' => '0.743' },
          'C6' => { 'dest_locn' => 'C6', 'dest_conc' => '0.743' },
          'D6' => { 'dest_locn' => 'D6', 'dest_conc' => '0.743' },
          'E6' => { 'dest_locn' => 'E6', 'dest_conc' => '0.743' },
          'F6' => { 'dest_locn' => 'F6', 'dest_conc' => '0.743' },
          'G6' => { 'dest_locn' => 'G6', 'dest_conc' => '0.743' },
          'H6' => { 'dest_locn' => 'H6', 'dest_conc' => '0.743' },
          'A7' => { 'dest_locn' => 'A7', 'dest_conc' => '0.743' },
          'B7' => { 'dest_locn' => 'B7', 'dest_conc' => '0.743' },
          'C7' => { 'dest_locn' => 'C7', 'dest_conc' => '0.743' },
          'D7' => { 'dest_locn' => 'D7', 'dest_conc' => '0.743' },
          'E7' => { 'dest_locn' => 'E7', 'dest_conc' => '0.743' },
          'F7' => { 'dest_locn' => 'F7', 'dest_conc' => '0.743' },
          'G7' => { 'dest_locn' => 'G7', 'dest_conc' => '0.743' },
          'H7' => { 'dest_locn' => 'H7', 'dest_conc' => '0.743' },
          'A8' => { 'dest_locn' => 'A8', 'dest_conc' => '0.743' },
          'B8' => { 'dest_locn' => 'B8', 'dest_conc' => '0.743' },
          'C8' => { 'dest_locn' => 'C8', 'dest_conc' => '0.743' },
          'D8' => { 'dest_locn' => 'D8', 'dest_conc' => '0.743' },
          'E8' => { 'dest_locn' => 'E8', 'dest_conc' => '0.743' },
          'F8' => { 'dest_locn' => 'F8', 'dest_conc' => '0.743' },
          'G8' => { 'dest_locn' => 'G8', 'dest_conc' => '0.743' },
          'H8' => { 'dest_locn' => 'H8', 'dest_conc' => '14.314' },
          'A9' => { 'dest_locn' => 'A9', 'dest_conc' => '14.314' },
          'B9' => { 'dest_locn' => 'B9', 'dest_conc' => '14.314' },
          'C9' => { 'dest_locn' => 'C9', 'dest_conc' => '14.314' },
          'D9' => { 'dest_locn' => 'D9', 'dest_conc' => '14.314' },
          'E9' => { 'dest_locn' => 'E9', 'dest_conc' => '14.314' },
          'F9' => { 'dest_locn' => 'F9', 'dest_conc' => '14.314' },
          'G9' => { 'dest_locn' => 'G9', 'dest_conc' => '14.314' },
          'H9' => { 'dest_locn' => 'H9', 'dest_conc' => '14.314' },
          'A10' => { 'dest_locn' => 'A10', 'dest_conc' => '14.314' },
          'B10' => { 'dest_locn' => 'B10', 'dest_conc' => '14.314' },
          'C10' => { 'dest_locn' => 'C10', 'dest_conc' => '14.314' },
          'D10' => { 'dest_locn' => 'D10', 'dest_conc' => '14.314' },
          'E10' => { 'dest_locn' => 'E10', 'dest_conc' => '14.314' },
          'F10' => { 'dest_locn' => 'F10', 'dest_conc' => '14.314' },
          'G10' => { 'dest_locn' => 'G10', 'dest_conc' => '14.314' },
          'H10' => { 'dest_locn' => 'H10', 'dest_conc' => '14.314' },
          'A11' => { 'dest_locn' => 'A11', 'dest_conc' => '14.314' },
          'B11' => { 'dest_locn' => 'B11', 'dest_conc' => '14.314' },
          'C11' => { 'dest_locn' => 'C11', 'dest_conc' => '14.314' },
          'D11' => { 'dest_locn' => 'D11', 'dest_conc' => '14.314' },
          'E11' => { 'dest_locn' => 'E11', 'dest_conc' => '14.314' },
          'F11' => { 'dest_locn' => 'F11', 'dest_conc' => '14.314' },
          'G11' => { 'dest_locn' => 'G11', 'dest_conc' => '14.314' },
          'H11' => { 'dest_locn' => 'H11', 'dest_conc' => '14.314' },
          'A12' => { 'dest_locn' => 'A12', 'dest_conc' => '14.314' },
          'B12' => { 'dest_locn' => 'B12', 'dest_conc' => '14.314' },
          'C12' => { 'dest_locn' => 'C12', 'dest_conc' => '14.314' },
          'D12' => { 'dest_locn' => 'D12', 'dest_conc' => '14.314' },
          'E12' => { 'dest_locn' => 'E12', 'dest_conc' => '14.314' },
          'F12' => { 'dest_locn' => 'F12', 'dest_conc' => '14.314' },
          'G12' => { 'dest_locn' => 'G12', 'dest_conc' => '14.314' },
          'H12' => { 'dest_locn' => 'H12', 'dest_conc' => '14.314' }
        }

        expect(subject.class.compute_transfers(well_amounts, subject.binning_config, num_rows, num_cols)).to eq(expd_transfers)
      end
      # rubocop:enable Metrics/BlockLength

      it 'works when requiring compression due to number of occupied bins exceeding plate columns' do
        well_amounts = {
          'A1' => '1.0', 'B1' => '11.0', 'C1' => '21.0', 'D1' => '31.0', 'E1' => '41.0', 'F1' => '51.0', 'G1' => '61.0',
          'H1' => '71.0', 'A2' => '81.0', 'B2' => '91.0', 'C2' => '101.0', 'D2' => '111.0', 'E2' => '121.0'
        }
        expd_transfers = {
          'A1' => { 'dest_locn' => 'A1', 'dest_conc' => '0.029' },
          'B1' => { 'dest_locn' => 'B1', 'dest_conc' => '0.314' },
          'C1' => { 'dest_locn' => 'C1', 'dest_conc' => '0.6' },
          'D1' => { 'dest_locn' => 'D1', 'dest_conc' => '0.886' },
          'E1' => { 'dest_locn' => 'E1', 'dest_conc' => '1.171' },
          'F1' => { 'dest_locn' => 'F1', 'dest_conc' => '1.457' },
          'G1' => { 'dest_locn' => 'G1', 'dest_conc' => '1.743' },
          'H1' => { 'dest_locn' => 'H1', 'dest_conc' => '2.029' },
          'A2' => { 'dest_locn' => 'A2', 'dest_conc' => '2.314' },
          'B2' => { 'dest_locn' => 'B2', 'dest_conc' => '2.6' },
          'C2' => { 'dest_locn' => 'C2', 'dest_conc' => '2.886' },
          'D2' => { 'dest_locn' => 'D2', 'dest_conc' => '3.171' },
          'E2' => { 'dest_locn' => 'E2', 'dest_conc' => '3.457' }
        }

        expect(subject.class.compute_transfers(well_amounts, binning_config_large, num_rows, num_cols)).to eq(expd_transfers)
      end
    end

    context 'when generating destination concentrations' do
      it 'refactors the transfers hash correctly' do
        transfers_hash = {
          'A1' => { 'dest_locn' => 'A2', 'dest_conc' => 0.665 },
          'B1' => { 'dest_locn' => 'A1', 'dest_conc' => 0.343 },
          'C1' => { 'dest_locn' => 'A3', 'dest_conc' => 2.135 },
          'D1' => { 'dest_locn' => 'B3', 'dest_conc' => 3.123 },
          'E1' => { 'dest_locn' => 'C3', 'dest_conc' => 3.045 },
          'F1' => { 'dest_locn' => 'B2', 'dest_conc' => 0.743 },
          'G1' => { 'dest_locn' => 'C2', 'dest_conc' => 0.693 }
        }
        expected_dest_concs = {
          'A2' => 0.665,
          'A1' => 0.343,
          'A3' => 2.135,
          'B3' => 3.123,
          'C3' => 3.045,
          'B2' => 0.743,
          'C2' => 0.693
        }

        expect(subject.class.compute_destination_concentrations(transfers_hash)).to eq(expected_dest_concs)
      end
    end
  end

  shared_examples 'a concentration binned plate creator' do
    describe '#save!' do
      let!(:plate_creation_request) do
        stub_api_post('plate_creations',
                      payload: { plate_creation: {
                        parent: parent_uuid,
                        child_purpose: child_purpose_uuid,
                        user: user_uuid
                      } },
                      body: json(:plate_creation))
      end

      let!(:transfer_creation_request) do
        stub_api_post('transfer_request_collections',
                      payload: { transfer_request_collection: {
                        user: user_uuid,
                        transfer_requests: transfer_requests
                      } },
                      body: '{}')
      end

      it 'makes the expected requests' do
        # NB. qc assay post is done using v2 Api, whereas plate creation and transfers posts are using v1 Api
        expect(Sequencescape::Api::V2::QcAssay).to receive(:create).with("qc_results": dest_well_qc_attributes).and_return(true)
        expect(subject.save!).to eq true
        expect(plate_creation_request).to have_been_made
        expect(transfer_creation_request).to have_been_made
      end
    end
  end

  context '96 well plate' do
    let(:transfer_requests) do
      [
        { 'source_asset' => well_a1.uuid, 'target_asset' => '3-well-A1', 'submission_id' => well_a1.submission_ids.first, 'volume' => 10 },
        { 'source_asset' => well_b1.uuid, 'target_asset' => '3-well-A3', 'submission_id' => well_b1.submission_ids.first, 'volume' => 10 },
        { 'source_asset' => well_c1.uuid, 'target_asset' => '3-well-A2', 'submission_id' => well_c1.submission_ids.first, 'volume' => 10 },
        { 'source_asset' => well_d1.uuid, 'target_asset' => '3-well-B1', 'submission_id' => well_d1.submission_ids.first, 'volume' => 10 }
      ]
    end

    let(:dest_well_qc_attributes) do
      [
        { 'well_name' => 'A1', 'conc' => '0.429' },
        { 'well_name' => 'B1', 'conc' => '0.514' },
        { 'well_name' => 'A2', 'conc' => '1.0' },
        { 'well_name' => 'A3', 'conc' => '16.0' }
      ].each.map do |attribs|
        {
          'uuid' => 'child-uuid',
          'well_location' => attribs['well_name'],
          'key' => 'concentration',
          'value' => attribs['conc'],
          'units' => 'ng/ul',
          'cv' => 0,
          'assay_type' => 'Calculated',
          'assay_version' => 'Binning'
        }
      end
    end

    it_behaves_like 'a concentration binned plate creator'
  end
end
