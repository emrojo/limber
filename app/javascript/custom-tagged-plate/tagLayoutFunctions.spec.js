import { calculateTagLayout } from './tagLayoutFunctions'
import { wellNameToCoordinate } from 'shared/wellHelpers'

describe('calculateTagLayout', () => {

  const inputWells = [
    { position: 'A1', aliquotCount: 1, poolIndex: 1 },
    { position: 'B1', aliquotCount: 1, poolIndex: 1 },
    { position: 'C1', aliquotCount: 1, poolIndex: 1 },
    { position: 'A2', aliquotCount: 1, poolIndex: 2 },
    { position: 'B2', aliquotCount: 1, poolIndex: 1 },
    { position: 'C2', aliquotCount: 1, poolIndex: 2 },
    { position: 'A3', aliquotCount: 1, poolIndex: 1 },
    { position: 'B3', aliquotCount: 1, poolIndex: 1 },
    { position: 'C3', aliquotCount: 1, poolIndex: 1 },
    { position: 'A4', aliquotCount: 1, poolIndex: 1 },
    { position: 'C4', aliquotCount: 1, poolIndex: 1 }
  ]

  const tagGrp1 = {
    id: '1',
    name: 'Tag Group 1',
    tags: [
      { index: 1, oligo: 'ACTGAAAA' },
      { index: 2, oligo: 'ACTGAAAT' },
      { index: 3, oligo: 'ACTGAAAG' },
      { index: 4, oligo: 'ACTGAAAC' },
      { index: 5, oligo: 'ACTGAATA' },
      { index: 6, oligo: 'ACTGAATG' },
      { index: 7, oligo: 'ACTGAATC' },
      { index: 8, oligo: 'ACTGAATT' },
      { index: 9, oligo: 'ACTGAAGA' },
      { index: 10, oligo: 'ACTGAAGT' },
      { index: 11, oligo: 'ACTGAAGC' },
      { index: 12, oligo: 'ACTGAAGG' },
      { index: 13, oligo: 'CCTGAAGG' },
      { index: 14, oligo: 'CCTGAAGG' },
      { index: 15, oligo: 'CCTGAAGG' },
      { index: 16, oligo: 'CCTGAAGG' },
      { index: 17, oligo: 'CCTGAAGG' },
      { index: 18, oligo: 'CCTGAAGG' },
      { index: 19, oligo: 'CCTGAAGG' },
      { index: 20, oligo: 'CCTGAAGG' },
      { index: 21, oligo: 'CCTGAAGG' },
      { index: 22, oligo: 'CCTGAAGG' },
      { index: 23, oligo: 'CCTGAAGG' },
      { index: 24, oligo: 'CCTGAAGG' }

    ]
  }

  const tagGrp2 = {
    id: '2',
    name: 'Tag Group 2',
    tags: [
      { index: 101, oligo: 'GCTGAAAA' },
      { index: 102, oligo: 'GCTGAAAT' },
      { index: 103, oligo: 'GCTGAAAG' },
      { index: 104, oligo: 'GCTGAAAC' },
      { index: 105, oligo: 'GCTGAATA' },
      { index: 106, oligo: 'GCTGAATG' },
      { index: 107, oligo: 'GCTGAATC' },
      { index: 108, oligo: 'GCTGAATT' },
      { index: 109, oligo: 'GCTGAAGA' },
      { index: 110, oligo: 'GCTGAAGT' },
      { index: 111, oligo: 'GCTGAAGC' },
      { index: 112, oligo: 'GCTGAAGG' }
    ]
  }

  const tagGrpNonConseq = {
    id: '3',
    name: 'Tag Group 3',
    tags: [
      { index: 2, oligo: 'GCTGAAAA' },
      { index: 5, oligo: 'GCTGAAAT' },
      { index: 6, oligo: 'GCTGAAAG' },
      { index: 7, oligo: 'GCTGAAAC' },
      { index: 9, oligo: 'GCTGAATA' },
      { index: 10, oligo: 'GCTGAATG' },
      { index: 12, oligo: 'GCTGAATC' },
      { index: 13, oligo: 'GCTGAATT' },
      { index: 14, oligo: 'GCTGAAGA' },
      { index: 15, oligo: 'GCTGAAGT' },
      { index: 17, oligo: 'GCTGAAGC' },
      { index: 18, oligo: 'GCTGAAGG' }
    ]
  }

  const tagGrpShort = {
    id: '4',
    name: 'Tag Group 4',
    tags: [
      { index: 1, oligo: 'GCTGAAAA' },
      { index: 2, oligo: 'GCTGAAAT' },
      { index: 3, oligo: 'GCTGAAAG' },
      { index: 4, oligo: 'GCTGAAAC' },
      { index: 5, oligo: 'GCTGAATA' },
      { index: 6, oligo: 'GCTGAATG' },
    ]
  }

  const plateDims = { number_of_rows: 3, number_of_columns: 4 }

  it('returns null if no tag groups are supplied', () => {
    const response = calculateTagLayout(inputWells, plateDims, null, null, 'by_plate_seq', 'by_columns', 0)
    expect(response).toEqual(null)
  })

  it('returns null if tag group contains no tags', () => {
    const emptyTagGrp = { id: '3', name: 'Tag Group Empty', tags: []}
    const response = calculateTagLayout(inputWells, plateDims, emptyTagGrp, null, 'by_plate_seq', 'by_columns', 0)
    expect(response).toEqual(null)
  })

  it('returns null if no input wells are supplied', () => {
    const response = calculateTagLayout(null, plateDims, tagGrp1, tagGrp2, 'by_plate_seq', 'by_columns', 0)
    expect(response).toEqual(null)
  })

  it('returns null if no plate dimensions are supplied', () => {
    const response = calculateTagLayout(inputWells, null, tagGrp1, tagGrp2, 'by_plate_seq', 'by_columns', 0)
    expect(response).toEqual(null)
  })

  it('returns null if invalid plate dimensions are supplied', () => {
    const invalidPlateDims = { number_of_rows: 0, number_of_columns: 4 }
    const response = calculateTagLayout(inputWells, invalidPlateDims, tagGrp1, tagGrp2, 'by_plate_seq', 'by_columns', 0)
    expect(response).toEqual(null)
  })

  it('builds the wells to tag index array for sequential plate by column', () => {
    const outputWells = { 'A1': 1, 'B1': 2, 'C1': 3, 'A2': 4, 'B2': 5, 'C2': 6, 'A3': 7, 'B3': 8, 'C3': 9, 'A4': 10, 'C4': 11 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_seq', 'by_columns', 0)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for sequential plate by row', () => {
    const outputWells = { 'A1': 1, 'B1': 5, 'C1': 8, 'A2': 2, 'B2': 6, 'C2': 9, 'A3': 3, 'B3': 7, 'C3': 10, 'A4': 4, 'C4': 11 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_seq', 'by_rows', 0)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for fixed plate by column', () => {
    const outputWells = { 'A1': 1, 'B1': 2, 'C1': 3, 'A2': 4, 'B2': 5, 'C2': 6, 'A3': 7, 'B3': 8, 'C3': 9, 'A4': 10, 'C4': 12 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_fixed', 'by_columns', 0)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for fixed plate by row', () => {
    const outputWells = { 'A1': 1, 'B1': 5, 'C1': 9, 'A2': 2, 'B2': 6, 'C2': 10, 'A3': 3, 'B3': 7, 'C3': 11, 'A4': 4, 'C4': 12 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_fixed', 'by_rows', 0)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for by pool by column', () => {
    const outputWells = { 'A1': 1, 'B1': 2, 'C1': 3, 'A2': 1, 'B2': 4, 'C2': 2, 'A3': 5, 'B3': 6, 'C3': 7, 'A4': 8, 'C4': 9 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_pool', 'by_columns', 0)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for by pool by row', () => {
    const outputWells = { 'A1': 1, 'B1': 4, 'C1': 7, 'A2': 1, 'B2': 5, 'C2': 2, 'A3': 2, 'B3': 6, 'C3': 8, 'A4': 3, 'C4': 9 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_pool', 'by_rows', 0)

    expect(response).toEqual(outputWells)
  })

  // offsets for all 6 scenarios above (nb. need more tags in tag group)
  it('builds the wells to tag index array for sequential plate by column with offset', () => {
    const outputWells = { 'A1': 5, 'B1': 6, 'C1': 7, 'A2': 8, 'B2': 9, 'C2': 10, 'A3': 11, 'B3': 12, 'C3': 13, 'A4': 14, 'C4': 15 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_seq', 'by_columns', 4)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for sequential plate by row with offset', () => {
    const outputWells = { 'A1': 5, 'B1': 9, 'C1': 12, 'A2': 6, 'B2': 10, 'C2': 13, 'A3': 7, 'B3': 11, 'C3': 14, 'A4': 8, 'C4': 15 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_seq', 'by_rows', 4)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for fixed plate by column with offset', () => {
    const outputWells = { 'A1': 5, 'B1': 6, 'C1': 7, 'A2': 8, 'B2': 9, 'C2': 10, 'A3': 11, 'B3': 12, 'C3': 13, 'A4': 14, 'C4': 16 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_fixed', 'by_columns', 4)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for fixed plate by row with offset', () => {
    const outputWells = { 'A1': 5, 'B1': 9, 'C1': 13, 'A2': 6, 'B2': 10, 'C2': 14, 'A3': 7, 'B3': 11, 'C3': 15, 'A4': 8, 'C4': 16 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_plate_fixed', 'by_rows', 4)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for by pool by column with offset', () => {
    const outputWells = { 'A1': 5, 'B1': 6, 'C1': 7, 'A2': 5, 'B2': 8, 'C2': 6, 'A3': 9, 'B3': 10, 'C3': 11, 'A4': 12, 'C4': 13 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_pool', 'by_columns', 4)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for by pool by row with offset', () => {
    const outputWells = { 'A1': 5, 'B1': 8, 'C1': 11, 'A2': 5, 'B2': 9, 'C2': 6, 'A3': 6, 'B3': 10, 'C3': 12, 'A4': 7, 'C4': 13 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrp1, tagGrp2, 'by_pool', 'by_rows', 4)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for sequential plate by column when no tag group 1', () => {
    const outputWells = { 'A1': 101, 'B1': 102, 'C1': 103, 'A2': 104, 'B2': 105, 'C2': 106, 'A3': 107, 'B3': 108, 'C3': 109, 'A4': 110, 'C4': 111 }
    const response = calculateTagLayout(inputWells, plateDims, null, tagGrp2, 'by_plate_seq', 'by_columns', 0)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for sequential plate by column', () => {
    const outputWells = { 'A1': 2, 'B1': 5, 'C1': 6, 'A2': 7, 'B2': 9, 'C2': 10, 'A3': 12, 'B3': 13, 'C3': 14, 'A4': 15, 'C4': 17 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrpNonConseq, null, 'by_plate_seq', 'by_columns', 0)

    expect(response).toEqual(outputWells)
  })

  it('builds the wells to tag index array for sequential plate by column where not enough tags', () => {
    const outputWells = { 'A1': 1, 'B1': 2, 'C1': 3, 'A2': 4, 'B2': 5, 'C2': 6, 'A3': -1, 'B3': -1, 'C3': -1, 'A4': -1, 'C4': -1 }
    const response = calculateTagLayout(inputWells, plateDims, tagGrpShort, null, 'by_plate_seq', 'by_columns', 0)

    expect(response).toEqual(outputWells)
  })

})