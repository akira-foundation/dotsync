import Foundation

public enum Tool: String, Sendable {
    case claude
    case codex
    case generic

    public static func detect(path: String) -> Tool {
        switch (path as NSString).lastPathComponent {
        case ".claude": return .claude
        case ".codex": return .codex
        default: return .generic
        }
    }
}

public enum Allowlist {
    public static func gitignore(for tool: Tool) -> String {
        switch tool {
        case .claude: return claude
        case .codex: return codex
        case .generic: return generic
        }
    }

    public static let gitattributes = """
    *.md merge=union
    *.jsonl merge=union
    **/memory/*.md merge=union
    settings.json merge=jsonmerge
    keybindings.json merge=jsonmerge
    config.toml merge=union

    """

    public static func write(for tool: Tool, to repo: URL) throws {
        try Data(gitignore(for: tool).utf8)
            .write(to: repo.appendingPathComponent(".gitignore"), options: .atomic)
        try Data(gitattributes.utf8)
            .write(to: repo.appendingPathComponent(".gitattributes"), options: .atomic)
    }

    static let claude = """
    /*
    /.*
    !/.gitignore
    !/.gitattributes
    !/CLAUDE.md
    !/settings.json
    !/keybindings.json
    !/skills/
    !/agents/
    !/commands/
    !/hooks/
    !/plugins/
    /plugins/*
    !/plugins/config.json
    !/plugins/repos/
    .credentials.json
    settings.local.json

    """

    static let codex = """
    /*
    /.*
    !/.gitignore
    !/.gitattributes
    !/AGENTS.md
    !/codex.md
    !/config.toml
    !/keybindings.json
    !/hooks/
    !/rules/
    !/prompts/
    !/plugins/
    /plugins/*
    !/plugins/config.toml
    !/plugins/config.json
    auth.json
    .codex-global-state.json
    installation_id
    *.local.json

    """

    static let generic = """
    /*
    /.*
    !/.gitignore
    !/.gitattributes
    !/*.md
    !/*.toml
    !/config.json
    *.local.json
    *.key
    *.pem

    """
}
