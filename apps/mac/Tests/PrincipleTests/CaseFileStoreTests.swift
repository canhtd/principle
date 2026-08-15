import Foundation
import Testing

@testable import PrincipleCore

let caseFixture = CaseSummary(
    slug: "tri-hoan-viec-nho",
    problem: "Em cứ làm việc nhỏ trước.",
    realProblem: "Mục tiêu quý chưa được xếp hạng.",
    direction: "Chốt ba mục tiêu quý. Rồi log năm ngày.",
    price: "Phải bỏ vài việc đang dở.",
    flip: "Log cho thấy việc nhỏ mới là việc chặn đường.",
    followUp: "2026-08-22",
    goal: "Ra mắt bản 1.0",
    continues: "2026-08-14-ca-cu.md"
)

let caseDiagnosis = Diagnosis(kind: "Ca ưu tiên", why: "Mục tiêu chưa xếp hạng.")

let caseCorpus = CorpusStore(records: [
    PrincipleRecord(
        id: "life:5.6", part: "Nguyên tắc sống", chapter: "Chương 5", num: "5.6",
        title: "Hãy cân nhắc hậu quả bậc hai và bậc ba", body: "Thân bài.", hasBody: true)
])

@Suite("CaseFileStore — file ca")
struct CaseFileStoreTests {
    @Test("Lượt đầu ghi file ca đúng tên ngày-slug, đủ đề mục của template")
    func writesTheCaseFileFromTheTrailer() throws {
        let repo = try TempRepo(prefix: "case-file")
        try repo.writeCaseTemplate(TempRepo.caseTemplateFixture)

        let filed = try repo.caseStore.create(
            caseFixture,
            diagnosis: caseDiagnosis,
            principles: [PrincipleRef(id: "life:5.6", apply: "Bạn đang cân cảm giác, chưa cân giá trị kỳ vọng.")],
            corpus: caseCorpus,
            date: TempRepo.noon(august: 15)
        )

        #expect(filed.relativePath == "memory/cases/2026-08-15-tri-hoan-viec-nho.md")
        #expect(filed.indexFailure == nil)
        let text = try repo.fileText(at: filed.relativePath)
        #expect(text.hasPrefix("# tri-hoan-viec-nho\n"))
        for line in [
            "- **Ngày:** 2026-08-15",
            "- **Kiểu ca:** Ca ưu tiên",
            "- **Trạng thái:** mở",
            "- **Liên quan goal:** Ra mắt bản 1.0",
            "- **Tiếp nối ca:** 2026-08-14-ca-cu.md",
        ] {
            #expect(text.contains(line), "front matter is missing \(line)")
        }
        for heading in CaseDocument.builtInHeadings {
            #expect(text.contains("\n\(heading)\n"), "the file is missing \(heading)")
        }
        #expect(text.contains(caseFixture.problem))
        #expect(text.contains(caseFixture.realProblem))
        #expect(text.contains(caseFixture.direction))
        #expect(text.contains(caseFixture.price))
        #expect(text.contains(caseFixture.flip))
        #expect(text.contains(caseFixture.followUp))
        // The title is read from the corpus, the bridge is the engine's (AE2).
        #expect(
            text.contains(
                "- `life:5.6` — Hãy cân nhắc hậu quả bậc hai và bậc ba — Bạn đang cân cảm giác, chưa cân giá trị kỳ vọng."
            ))
        // CLAUDE.md: Kết quả stays empty until a real outcome arrives.
        #expect(text.hasSuffix("## Kết quả\n"))
    }

    /// A fresh clone has no template — and a repo whose template went missing
    /// must still close its memory loop.
    @Test("Không có _TEMPLATE.md vẫn ghi được, dùng đề mục có sẵn trong app")
    func filesWithoutATemplate() throws {
        let repo = try TempRepo(prefix: "case-no-template")

        let filed = try repo.caseStore.create(caseFixture, diagnosis: caseDiagnosis, date: TempRepo.noon(august: 15))

        let text = try repo.fileText(at: filed.relativePath)
        for heading in CaseDocument.builtInHeadings {
            #expect(text.contains("\n\(heading)\n"), "the file is missing \(heading)")
        }
        #expect(text.contains(caseFixture.direction))
    }

    /// The file belongs to the repo's memory protocol, not to the app: a repo
    /// that renames its sections gets its own names back.
    @Test("Template đổi tên đề mục thì file ca đi theo template")
    func followsTheTemplatesHeadings() throws {
        let repo = try TempRepo(prefix: "case-template")
        let renamed = (1...CaseDocument.builtInHeadings.count).map { "## Mục \($0)" }
        try repo.writeCaseTemplate("# Ca\n\n" + renamed.joined(separator: "\n\n") + "\n")

        let filed = try repo.caseStore.create(caseFixture, date: TempRepo.noon(august: 15))

        let text = try repo.fileText(at: filed.relativePath)
        for heading in renamed {
            #expect(text.contains("\n\(heading)\n"))
        }
        #expect(!text.contains(CaseDocument.builtInHeadings[0]))
    }

    /// Positional filling only works when the template still has the sections
    /// this composer knows how to fill; anything else is left alone.
    @Test("Template lạ số đề mục → quay về đề mục có sẵn, không nhét bừa")
    func ignoresATemplateItCannotFill() throws {
        let repo = try TempRepo(prefix: "case-odd-template")
        try repo.writeCaseTemplate("# Ca\n\n## Chỉ một mục\n")

        let filed = try repo.caseStore.create(caseFixture, date: TempRepo.noon(august: 15))

        let text = try repo.fileText(at: filed.relativePath)
        #expect(text.contains(CaseDocument.builtInHeadings[0]))
        #expect(!text.contains("## Chỉ một mục"))
    }

    @Test("Hai ca cùng slug cùng ngày → file thứ hai đổi tên, không đè lên file đầu")
    func dedupesTheFileName() throws {
        let repo = try TempRepo(prefix: "case-dedupe")

        let first = try repo.caseStore.create(caseFixture, date: TempRepo.noon(august: 15))
        let second = try repo.caseStore.create(
            CaseSummary(slug: caseFixture.slug, problem: "Ca khác cùng chủ đề."),
            date: TempRepo.noon(august: 15))

        #expect(first.relativePath == "memory/cases/2026-08-15-tri-hoan-viec-nho.md")
        #expect(second.relativePath == "memory/cases/2026-08-15-tri-hoan-viec-nho-2.md")
        #expect(try repo.fileText(at: first.relativePath).contains(caseFixture.problem))
        #expect(try repo.fileText(at: second.relativePath).contains("Ca khác cùng chủ đề."))
    }

    /// A principle the corpus does not know still gets its bridge written down;
    /// what it never gets is a title the app made up (AE2).
    @Test("Corpus không biết id thì dòng nguyên tắc chỉ còn id và câu bắc cầu")
    func writesUnknownPrinciplesWithoutATitle() throws {
        let repo = try TempRepo(prefix: "case-unknown-id")

        let filed = try repo.caseStore.create(
            caseFixture,
            principles: [PrincipleRef(id: "life:9.9", apply: "Nó cắt vào đây.")],
            corpus: caseCorpus,
            date: TempRepo.noon(august: 15))

        #expect(try repo.fileText(at: filed.relativePath).contains("- `life:9.9` — Nó cắt vào đây.\n"))
    }
}
