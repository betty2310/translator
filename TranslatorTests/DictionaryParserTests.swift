import Foundation
import Testing
@testable import Translator

/// Canned records, trimmed from what Dictionary Services returns for the VIETTIEN and Oxford dictionaries.
struct DictionaryParserTests {
    static let anhViet = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <html xmlns:d="http://www.apple.com/DTDs/DictionaryService-1.0.rng"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /></head><body><d:entry id="372854" d:title="take">
    <h1>take</h1>
    <pre>
    <span class="c">™</span><a onclick="this.firstChild.play()" class="t"><audio src=".s/take.mp3"></audio>▸</a><ul><p class="ap"></p> <span class="m"> take /teɪk/
    </span><img src="1.png" /><span class="lt"> dt.</span>
       ◦  sự cầm, sự nắm, sự lấy
       ◦  chầu, mẻ<li>a great take of fish:<font color="#1d66da"> mẻ cá lớn</font></li>   ◦  (điện ảnh) cảnh quay (vào phim)
    <img src="1.png" /><span class="lt"> ng.đt. took; taken</span>
       ◦  cầm, nắm, giữ<li>to take something in one's hand:<font color="#1d66da"> cầm vật gì trong tay</font></li><span class="m"> to take after</span>
       ◦  giống<li>he takes after his uncle:<font color="#1d66da"> nó giống ông chú nó</font></li><span class="fi">

    THUẬT NGỮ</span><span class="thn">
    Ng.: dầu khí</span>
    ['teɪk]
       ◦<span class="dk1"> lấy, thu được</span>
          ▪ <span class="dk2">take a core</span>: lấy mẫu lõi</ul>
    </pre>
    </d:entry></body></html>
    """

    static let vietAnh = """
    <html><body><d:entry id="40705" d:title="chào"><h1>chào</h1><pre>
    <span class="c">™</span><ul><p class="ap"></p><span class="z3"> [chào]</span>
       ◦  to bow; to greet<li>Chào cờ:<font color="#7db1f9"> To salute the flag</font></li>   ◦  good-bye; bye<li><span class="z4">Tiếng chào cao hơn mâm cỗ</span></li>   ◦  A word of greeting is more precious than a hearty meal</ul>
    </pre></d:entry></body></html>
    """

    static let vietViet = """
    <html><body><d:entry id="4661" d:title="chào"><h1>chào</h1><pre>
    <span class="c">™</span> <span class="mtnew">chào: </span><ul><li class="a2">[cảm từ] Tiếng kêu lên khi chán nản.</li></ul><hr /><span class="mtnew">chào: </span><ul><li class="a">[đg.từ] 1. Nói hoặc ra hiệu, tỏ lòng kính trọng. 2. Mời khách vào ăn uống, mua bán: Nhà hàng chào khách.</li></ul>
    </pre></d:entry></body></html>
    """

    static let oxford = """
    <html><body><d:entry id="m_en_gbus0460730" d:title="hello" class="entry"><span class="hg x_xh0"><span role="text" homograph="1" class="hw">hel<span class="hsb"/>lo<span class="gp ty_hom tg_hw"> 1 </span></span><span class="prx"> | <span class="ph t_respell">həˈlō<span class="gp tg_ph">, </span></span><span class="ph t_respell">heˈlō</span> | </span></span><span class="sg"><span class="se1 x_xd0"><span role="text" class="posg x_xdh"><span d:pos="1" class="pos"><span class="gp tg_pos">exclamation </span></span></span><span class="msDict x_xd1 t_core"><span role="text" class="df">used as a greeting<d:def/></span><span role="text" class="gp tg_df">: </span><span role="text" class="eg"><span class="ex"> hello there, Katie!</span></span></span><span class="msDict x_xd1 hasSn t_subsense"><span role="text" class="gp sn tg_msDict">  • </span><span role="text" class="lg"><span class="ge">British English </span></span><span role="text" class="df">used to express surprise</span></span></span><span class="se1 x_xd0"><span role="text" class="posg x_xdh"><span class="pos"><span class="gp tg_pos">noun </span></span><span class="infg"><span class="gp tg_infg">(</span><span class="sy">plural </span><span class="inf">hellos</span><span class="gp tg_infg">) </span></span></span><span class="msDict x_xd1 t_core"><span role="text" class="df">an utterance of “hello”; a greeting</span></span></span></span><span role="text" class="etym x_xo0"><span class="gp x_xoLblBlk ty_label tg_etym">ORIGIN </span><span class="x_xo1">early 19th century: variant of earlier <span class="ff">hollo</span>.</span></span></d:entry></body></html>
    """

    @Test func readsVietTienHeadwordSectionsSensesAndExamples() throws {
        let entry = try #require(DictionaryParser.entry(dictionary: "VIETTIEN Anh-Việt (v6.0b1.b5)", term: "take", records: [Self.anhViet]))
        #expect(entry.headword == "take")
        #expect(entry.pronunciations == ["/teɪk/"])
        #expect(entry.dictionaryName == "VIETTIEN Anh-Việt")
        let noun = entry.sections[0]
        #expect(noun.kind == .main && noun.title == "noun" && noun.note == nil)
        #expect(noun.senses.map(\.text) == ["sự cầm, sự nắm, sự lấy", "chầu, mẻ", "cảnh quay (vào phim)"])
        #expect(noun.senses[1].examples == [.init(text: "a great take of fish", translation: "mẻ cá lớn")])
        #expect(noun.senses[2].labels == ["điện ảnh"])
        let verb = entry.sections[1]
        #expect(verb.title == "transitive verb" && verb.note == "took; taken")
        #expect(verb.senses[0].examples.first?.translation == "cầm vật gì trong tay")
        let phrase = entry.sections[2]
        #expect(phrase.kind == .phrase && phrase.title == "to take after")
        #expect(phrase.senses.map(\.text) == ["giống"])
    }

    @Test func keepsSpecializedTermsAsExtra() throws {
        let entry = try #require(DictionaryParser.entry(dictionary: "VT", term: "take", records: [Self.anhViet]))
        let extra = try #require(entry.sections.last)
        #expect(extra.kind == .extra && extra.title == "Thuật ngữ · dầu khí")
        #expect(extra.senses.map(\.text) == ["lấy, thu được"])
        #expect(extra.senses[0].examples == [.init(text: "take a core", translation: "lấy mẫu lõi")])
    }

    @Test func readsVietAnhWithIdioms() throws {
        let entry = try #require(DictionaryParser.entry(dictionary: "VT", term: "chào", records: [Self.vietAnh]))
        #expect(entry.headword == "chào" && entry.pronunciations.isEmpty)
        #expect(entry.sections[0].title == nil)
        #expect(entry.sections[0].senses.map(\.text) == ["to bow; to greet", "good-bye; bye"])
        #expect(entry.sections[1].kind == .phrase && entry.sections[1].title == "Tiếng chào cao hơn mâm cỗ")
        #expect(entry.sections[1].senses.map(\.text) == ["A word of greeting is more precious than a hearty meal"])
    }

    @Test func readsVietVietDefinitionsWithBracketedPartOfSpeech() throws {
        let entry = try #require(DictionaryParser.entry(dictionary: "VT", term: "chào", records: [Self.vietViet]))
        #expect(entry.sections.map(\.title) == ["interjection", "verb"])
        #expect(entry.sections[1].senses.map(\.text) == ["Nói hoặc ra hiệu, tỏ lòng kính trọng.", "Mời khách vào ăn uống, mua bán: Nhà hàng chào khách."])
    }

    @Test func readsOxfordEntries() throws {
        let entry = try #require(DictionaryParser.entry(dictionary: "New Oxford American Dictionary", term: "hello", records: [Self.oxford]))
        #expect(entry.headword == "hello")
        #expect(entry.pronunciations == ["/həˈlō/", "/heˈlō/"])
        #expect(entry.sections.map(\.title) == ["exclamation", "noun", "Origin"])
        let exclamation = entry.sections[0]
        #expect(exclamation.senses[0] == .init(text: "used as a greeting", examples: [.init(text: "hello there, Katie!")]))
        #expect(exclamation.senses[1] == .init(text: "used to express surprise", labels: ["British English"], isSubsense: true))
        #expect(entry.sections[1].note == "(plural hellos)")
        #expect(entry.sections[2].kind == .extra && entry.sections[2].senses[0].text == "early 19th century: variant of earlier hollo.")
    }

    @Test func survivesMalformedHTML() {
        let root = HTMLTree.parse("<pre><ul><font color=green><b> o xem caterpillar</b></font></ul></span></pre>")
        #expect(DictionaryParser.squeezed(root.text) == "o xem caterpillar")
        #expect(HTMLTree.decodeEntities("a &amp; b &#233; &#x1EBF; &bogus;") == "a & b é ế &bogus;")
    }

    @Test func readsPlainTextAsFallback() throws {
        let text = "cát\n™ [cát]\ndanh từ\n◦ Sand\n◦ Grain"
        let entry = try #require(DictionaryParser.entry(dictionary: "VT", term: "cát", plainText: text))
        #expect(entry.sections.count == 1 && entry.sections[0].title == "noun")
        #expect(entry.sections[0].senses.map(\.text) == ["Sand", "Grain"])
    }

    @Test func mapsVietnamesePartsOfSpeech() {
        #expect(DictionaryParser.partOfSpeech(" dt.").label == "noun")
        #expect(DictionaryParser.partOfSpeech("n.đt. (went, gone)") == ("intransitive verb", "(went, gone)"))
        #expect(DictionaryParser.partOfSpeech("dt., số nhiều goes") == ("noun", "số nhiều goes"))
        #expect(DictionaryParser.partOfSpeech("thán từ").label == "interjection")
        #expect(DictionaryParser.partOfSpeech("đại từ").label == "pronoun")
        #expect(DictionaryParser.partOfSpeech("exclamation").label == "exclamation")
    }

    @Test func splitsNumberedDefinitions() {
        #expect(DictionaryParser.numberedParts("1. Nói. 2. Tỏ sự kính cẩn.") == ["Nói.", "Tỏ sự kính cẩn."])
        #expect(DictionaryParser.numberedParts("Có 2. không") == ["Có 2. không"])
    }

    @Test func previewKeepsMainSectionsAndOneExamplePerSense() throws {
        let entry = try #require(DictionaryParser.entry(dictionary: "VT", term: "take", records: [Self.anhViet]))
        let preview = entry.preview(rows: 100)
        #expect(!preview.sections.contains { $0.kind == .extra })
        #expect(preview.sections.allSatisfy { $0.senses.allSatisfy { $0.examples.count <= 1 } })
        let short = entry.preview(rows: 3)
        #expect(short.sections.count == 1 && short.sections[0].senses.count == 2 && short.sections[0].hasHiddenSenses)
        #expect(short != entry)
    }

    @Test func numbersSensesOnlyWhenThereAreSeveral() {
        typealias Sense = DictionaryEntry.Sense
        #expect(DictionarySectionView.markers(for: [Sense(text: "a")]) == [nil])
        #expect(DictionarySectionView.markers(for: [Sense(text: "a")], numbered: true) == ["1"])
        #expect(DictionarySectionView.markers(for: [Sense(text: "a"), Sense(text: "b", isSubsense: true), Sense(text: "c")]) == ["1", "•", "2"])
    }
}
