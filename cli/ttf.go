package main

import (
	"encoding/binary"
	"fmt"
	"os"
)

// glyphNames reads the names in a font's post table. The app font names each
// glyph after the ligature it renders, ":ghostty:" and the like, so these are
// what the icon map has to reference.
func glyphNames(path string) (map[string]bool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	tables, err := tableOffsets(data)
	if err != nil {
		return nil, err
	}

	post, ok := tables["post"]
	if !ok {
		return nil, fmt.Errorf("no post table")
	}
	if post.end() > len(data) {
		return nil, fmt.Errorf("post table runs past the end of the file")
	}
	body := data[post.offset:post.end()]
	if len(body) < 34 {
		return nil, fmt.Errorf("post table too short")
	}

	// Only version 2.0 carries names. Anything else leaves nothing to compare
	// against, which callers treat as "cannot tell" rather than a mismatch.
	if binary.BigEndian.Uint32(body) != 0x00020000 {
		return nil, nil
	}

	count := int(binary.BigEndian.Uint16(body[32:]))
	indexEnd := 34 + 2*count
	if indexEnd > len(body) {
		return nil, fmt.Errorf("glyph index runs past the post table")
	}

	var pascal []string
	for pos := indexEnd; pos < len(body); {
		size := int(body[pos])
		if pos+1+size > len(body) {
			break
		}
		pascal = append(pascal, string(body[pos+1:pos+1+size]))
		pos += 1 + size
	}

	names := make(map[string]bool, count)
	for i := 0; i < count; i++ {
		index := int(binary.BigEndian.Uint16(body[34+2*i:]))
		// Below 258 the index names one of the standard Macintosh glyphs,
		// none of which is a ligature this config would reference.
		if index < 258 {
			continue
		}
		if n := index - 258; n < len(pascal) {
			names[pascal[n]] = true
		}
	}
	return names, nil
}

type tableRecord struct {
	offset int
	length int
}

func (t tableRecord) end() int { return t.offset + t.length }

func tableOffsets(data []byte) (map[string]tableRecord, error) {
	if len(data) < 12 {
		return nil, fmt.Errorf("not a font file")
	}
	count := int(binary.BigEndian.Uint16(data[4:]))
	if 12+16*count > len(data) {
		return nil, fmt.Errorf("table directory runs past the end of the file")
	}

	tables := make(map[string]tableRecord, count)
	for i := 0; i < count; i++ {
		record := data[12+16*i:]
		tables[string(record[0:4])] = tableRecord{
			offset: int(binary.BigEndian.Uint32(record[8:])),
			length: int(binary.BigEndian.Uint32(record[12:])),
		}
	}
	return tables, nil
}
