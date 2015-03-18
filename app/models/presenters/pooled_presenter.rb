#This file is part of Illumina-B Pipeline is distributed under the terms of GNU General Public License version 3 or later;
#Please refer to the LICENSE and README files for information on licensing and authorship of this file.
#Copyright (C) 2011,2012,2015 Genome Research Ltd.
module Presenters
  class PooledPresenter < PlatePresenter
    include Presenters::Statemachine
    def plate
      labware
    end

    def walk_source
      PlateWalking::Walker.new(plate_to_walk, plate_to_walk.wells)
    end

    def walk_destination
      PlateWalking::Walker.new(labware, labware.wells)
    end

    Barcode = Struct.new(:prefix,:number,:suffix,:study,:type)

    def get_tube_barcodes
      plate.tubes.map do |tube|
        Barcode.new(tube.barcode.prefix,tube.barcode.number,nil,prioritized_name(tube.name, 10),tube.barcode.type)
      end
    end

  end
end
