#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p .validation/media
say -v Samantha -r 160 -o '.validation/media/English sample.aiff' 'Hello. This is a local subtitle test. The meeting starts at nine tomorrow.'
say -v 'Yuna (Korean (South Korea))' -r 160 -o '.validation/media/한국어 예제.aiff' '안녕하세요. 이것은 로컬 자막 테스트입니다. 내일 회의는 아홉 시에 시작합니다.'
say -v Kyoko -r 160 -o '.validation/media/日本語 sample.aiff' 'こんにちは。これは字幕のテストです。明日の会議は九時に始まります。'
say -v Tingting -r 160 -o '.validation/media/中文 sample.aiff' '你好。这是本地字幕测试。明天的会议九点开始。'
