# frozen_string_literal: true

#
# Class Limber::Plate provides a client side representation of Sequencescape plates
#
# @author Genome Research Ltd.
#
class Limber::Plate < Sequencescape::Plate
  delegate :number_of_pools, :pcr_cycles, :library_type_name, :insert_size, :ready_for_automatic_pooling?,
           :ready_for_custom_pooling?, :submissions, :primer_panel,
           to: :pools_info

  #
  # The width of the plate. Assumes a 3:2 ratio
  #
  # @return [Integer] Plate width in wells
  #
  def number_of_columns
    Math.sqrt(size / 6).to_i * 3
  end

  #
  # The height of the plate. Assumes a 4:3 ratio
  #
  # @return [Integer] Plate height in wells
  #
  def number_of_rows
    Math.sqrt(size / 6).to_i * 2
  end

  def pools_info
    @pools_info ||= Pools.new(pools)
  end

  def role
    label.prefix
  end

  def purpose
    plate_purpose
  end

  def tagged?
    first_filled_well = wells.detect { |w| w.aliquots.first }
    first_filled_well && first_filled_well.aliquots.first.tag.identifier.present?
  end

  def human_barcode
    "#{barcode.prefix}#{barcode.number}"
  end

  def plate?
    true
  end

  def tube?
    false
  end

  private

  def well_uuids_to_location
    @well_uuids_to_map_description ||= wells.each_with_object({}) do |well, hash|
      hash[well.uuid] = well.location
    end
  end
end
