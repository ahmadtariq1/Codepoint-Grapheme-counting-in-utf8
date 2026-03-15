Counting codepoints and graphemes [visible characters]

Quick note: Please update your own path for including win32a.inc to run it properly
check testcases for testing

Codepoint/Rune counting:
Variable length parsing: Based on the specification, simple comparisons + bitwise operations can help in finding the number of bytes in a codepoint. The important part is to reconstruct from distributed bytes into a scalar value which is done through bitmasking + shift left operation. Refer to .charntorune for checking implementation.

Checks for malformed sequences and overlong sequences have also been implemented:
1 - missing continuation bytes
2 - invalid leading bytes
3 - verifying codepoint encoded using the minimum required bytes.

Grapheme counting:
Full implementation of grapheme counting is not done, some simplification has been done but it gives a good idea on how to approach the problem. Let's leave some work for GSOC as well.

Overview:
1-Get code point value → 2-find attribute → 3-compare it with previous codepoint attribute → 4-if it is the right match → 5-move ahead otherwise break and increment count → 6- if there is an attribute which requires history (like knowing what was there 2-3 bytes prior) then a state machine is used to cater it.

There are 3 types of properties:
1 - Standard Properties (Bitmask compatible) [CR, LF etc]: These can be handled pretty easily. They only require comparison of left and right codepoint and no history has to be maintained. Each "Left Property" gets a 32-bit integer row. Each bit in that row represents a "Right Property" that it should glue to. The CPU evaluates complex grapheme boundaries in a single clock cycle using the BT (Bit Test) instruction. If the bit is 1, the codepoints glue. If 0, they break. Essentially we have properties of left and right stored in an integer, and we are checking if the properties that left matches with exist in right. Note: matches here mean the right combination dictated by unicode rules, not literal values matching. For these cases we precompute these values and store them as they are not going to change.

2 - Hangul Syllable Properties [L, V, T, LV, LVT].

3 - State-Machine Properties [GB9C, 11, 12, 13]: They can be handled by creating a state machine (DFA). It is not difficult to implement but time taking for different rules so one of them has been implemented. Regional Indicators are handled by tracking a boolean on the stack. This ensures consecutive country code letters strictly form pairs and break into separate clusters upon a third occurrence.

Step Explanations:
1 - Get code point value: check chartorune.
2 - Find Attribute: Current Implementation is oversimplified but follows the suckless approach which is creating a data structure based on the intervals of different attributes and then running bin search to find the attribute. Currently we have a small range of intervals through which we do linear search for the sake of simplicity. In actual there are over 1000 distinct ranges.