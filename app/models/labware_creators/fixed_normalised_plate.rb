# frozen_string_literal: true

module LabwareCreators
  # Handles the generation of fixed normalised plate.
  # This type of plate has a source and diluent volume specified in the purpose configuration.
  # Wells are stamped across without any rearrangements.
  # The child well concentrations are calculated and written as qc_results on the plate.
  class FixedNormalisedPlate < StampedPlate
    validate :wells_with_aliquots_have_concentrations?

    def parent
      @parent ||= Sequencescape::Api::V2.plate_with_custom_includes(
        'wells.aliquots,wells.qc_results,wells.requests_as_source.request_type,wells.aliquots.request.request_type',
        uuid: parent_uuid
      )
    end

    # Validate that any wells with aliquots have associated qc_result concentration values.
    def wells_with_aliquots_have_concentrations?
      concs_missing = wells_with_missing_concs
      return if concs_missing.size.zero?

      msg = 'wells missing a concentration (have you uploaded concentrations via QuantHub?):'
      errors.add(:parent, "#{msg} #{concs_missing.join(', ')}")
    end

    # The configuration from the plate purpose.
    # Contains source and diluent volumes used to calculate destination concentrations.
    def fixed_normalisation_config
      purpose_config.fetch(:fixed_normalisation)
    end

    def fixed_norm_calculator
      @fixed_norm_calculator ||= Utility::FixedNormalisationCalculator.new(fixed_normalisation_config)
    end

    private

    def wells_with_missing_concs
      parent.wells.each_with_object([]) do |well, concs_missing|
        next if well.aliquots.blank?

        concs_missing << well.location if well.latest_concentration.nil?
      end
    end

    def request_hash(source_well, child_plate, additional_parameters)
      {
        'source_asset' => source_well.uuid,
        'target_asset' => child_plate.wells.detect do |child_well|
          child_well.location == transfer_hash[source_well.location]['dest_locn']
        end&.uuid,
        'volume' => fixed_norm_calculator.source_volume.to_s
      }.merge(additional_parameters)
    end

    def transfer_hash
      @transfer_hash ||= fixed_norm_calculator.compute_well_transfers(parent)
    end

    def dest_well_qc_attributes
      @dest_well_qc_attributes ||=
        fixed_norm_calculator.construct_dest_qc_assay_attributes(child.uuid, 'Fixed Normalisation', transfer_hash)
    end

    def after_transfer!
      Sequencescape::Api::V2::QcAssay.create(
        qc_results: dest_well_qc_attributes
      )
    end
  end
end