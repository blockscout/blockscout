package main

import (
	"io/ioutil"
	"log"
	"strings"
)

func main() {
	input, err := ioutil.ReadFile("mix.lock")
	if err != nil {
		log.Fatalln(err)
	}

	lines := strings.Split(string(input), "\n")
	search1 := "\"ex_abi\": {:hex, :ex_abi, \"0.6.0\", \"8cf1fef9490dea0834bc201d399635e72178df05dea87b1c933478762dede142\", [:mix], [{:ex_keccak, \"~> 0.7.1\", [hex: :ex_keccak, repo: \"hexpm\", optional: false]}, {:jason, \"~> 1.4\", [hex: :jason, repo: \"hexpm\", optional: false]}], \"hexpm\", \"b03e5fe07371db3ceceb2d536cc32658dcba47b79952469e3e71d7690495e8d8\"},"
	replace1 := "  \"ex_abi\": {:hex, :ex_abi, \"0.5.16\", \"735f14937bc3c8fd53c38f02936ef8bf93d26a0b999cb0230b105d901530acaf\", [:mix], [{:ex_keccak, \"~> 0.6.0\", [hex: :ex_keccak, repo: \"hexpm\", optional: false]}, {:jason, \"~> 1.4\", [hex: :jason, repo: \"hexpm\", optional: false]}], \"hexpm\", \"82ee815f438c5d29ddc3e151a23a9eb5e906f3472cc6f5005b6f5a7f37332efe\"},"
	search2 := "\"ex_keccak\": {:hex, :ex_keccak, \"0.7.1\", \"0169f4b0c5073c5df61581d6282b12f1a1b764dcfcda4eeb1c819b5194c9ced0\", [:mix], [{:rustler, \">= 0.0.0\", [hex: :rustler, repo: \"hexpm\", optional: true]}, {:rustler_precompiled, \"~> 0.6.1\", [hex: :rustler_precompiled, repo: \"hexpm\", optional: false]}], \"hexpm\", \"c18c19f66b6545b4b46b0c71c0cc0079de84e30b26365a92961e91697e8724ed\"},"
	replace2 := "  \"ex_keccak\": {:hex, :ex_keccak, \"0.6.0\", \"0e1f8974dd6630dd4fb0b64f9eabbceeffb9675da3ab95dea653798365802cf4\", [:mix], [{:rustler, \"~> 0.26\", [hex: :rustler, repo: \"hexpm\", optional: false]}], \"hexpm\", \"84b20cfe6a063edab311b2c8ff8b221698c84cbd5fbdba059e51636540142538\"},"

	for i, line := range lines {
		if strings.Contains(line, search1) {
			lines[i] = replace1
		} else if strings.Contains(line, search2) {
			lines[i] = replace2
		}
	}
	output := strings.Join(lines, "\n")
	err = ioutil.WriteFile("mix.lock", []byte(output), 0644)
	if err != nil {
		log.Fatalln(err)
	}
}
