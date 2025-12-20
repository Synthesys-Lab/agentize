# Language Requirements

## Repository Language Rule
**All files written in this repository must be in English**, including:
- Source code (variable names, function names, class names, API endpoints)
- Comments and documentation
- Error messages and log output
- Git commit messages and branch names
- Configuration files and scripts
- README files and documentation
- Test files and test data
- Example code and tutorials
- Issue titles and descriptions
- Pull request titles and descriptions
- Any text that becomes part of the project's permanent record

## AI Agent Language Rules

### Conversation Language
**In explanatory conversations only**, the AI agent may use the same language that the user used in their question:
- If the user asks in Chinese, the agent may respond in Chinese
- If the user asks in English, the agent responds in English
- This applies ONLY to explanatory text in the conversation

### Actions Affecting the Repository
**When the AI agent performs any action that affects the repository**, all content MUST be in English:
- Code modifications (all identifiers, comments, strings)
- Documentation updates
- Git commit messages
- File creation or modification
- TODO items and task descriptions
- Memory creation related to the project
- Any text that will be saved in the repository

### Key Principle
The only non-English text allowed in this repository exists in:
1. This rule file itself (for demonstrating incorrect examples)
2. AI agent's explanatory responses in conversations (not affecting repository files)

## Examples

### Correct (English code)
```cpp
// Calculate the maximum delay for the circuit
int calculateMaxDelay(CircuitNode* root) {
    if (!root) {
        printf("Error: Invalid circuit node\n");
        return -1;
    }
    return root->delay;
}
```

### Incorrect (Chinese in code)
```cpp
// 计算电路的最大延迟
int 计算最大延迟(CircuitNode* 根节点) {
    if (!根节点) {
        printf("错误：无效的电路节点\n");
        return -1;
    }
    return 根节点->delay;
}
```

### Incorrect (Other languages in code)
Any non-English identifiers, comments, or strings in code are prohibited regardless of language (Spanish, Korean, French, etc.).

### Correct (English commit message)
```
git commit -m "Add support for pipeline scheduling optimization"
```

### Incorrect (Non-English commit messages)
```bash
git commit -m "添加流水线调度优化支持"  # Chinese - prohibited
git commit -m "Añadir soporte..."        # Spanish - prohibited
```

## AI Agent Behavior Examples

### Correct: English in repository actions
**User:** 请帮我添加一个新的compute操作
**AI Agent:** (creates file with English content)
```mlir
// New compute operation for element-wise addition
dsa.compute_add %in1, %in2 : (f32, f32) -> f32
```

### Incorrect: Non-English in repository actions
**User:** 请帮我添加一个新的compute操作
**AI Agent:** (creates file with Chinese content)
```mlir
// 新的计算操作用于逐元素加法
dsa.compute_add %in1, %in2 : (f32, f32) -> f32
```

### Correct: Conversation in user's language
**User:** 这个函数是做什么的？
**AI Agent:** 这个函数用于计算电路的最大延迟。它遍历所有节点并找出关键路径上的最大延迟值。

### Correct: English TODO items
**AI Agent creates TODO:**
```
- Implement pipeline scheduling optimization
- Add support for 2D memory operations
- Update documentation for new compute operations
```

### Incorrect: Non-English TODO items
**AI Agent creates TODO:**
```
- 实现流水线调度优化  # Chinese - prohibited
```

## Special Characters and Emoji Rule

### Prohibited Characters

**Do NOT use emojis or special Unicode symbols in repository files.** This includes:
- Emoji checkmarks and crosses: ✅ ❌ (U+2705, U+274C)
- Decorative emojis: 🚀 📝 💡 🔧 🎯 📋 ⭐
- CJK characters (except in this rule file as examples)
- Other Unicode pictographs and symbols

### Allowed Exceptions

Only these four special characters are permitted:
- ⚙ (U+2699) - Gear symbol for settings/configuration
- ⚠ (U+26A0) - Warning symbol for alerts
- ✓ (U+2713) - Simple check mark
- ✗ (U+2717) - Simple x mark

### Examples

**Correct (ASCII or allowed symbols):**
```markdown
- [x] Task completed
- [ ] Task pending
- PASS: All tests passed
- FAIL: 3 tests failed
- WARNING: Deprecated API usage
```

**Incorrect (prohibited emojis):**
```markdown
- ✅ Task completed     # Use [x] instead
- ❌ Task failed        # Use [ ] or FAIL instead
- 🚀 New feature        # Remove emoji
- 📝 Documentation      # Remove emoji
```

**Correct (using allowed symbols):**
```markdown
⚠ Warning: This API is deprecated
✓ Build passed
✗ Test failed
```

### AI Agent Behavior

When performing repository actions, AI agents MUST:
- Use ASCII text markers: `[x]`, `[ ]`, `PASS`, `FAIL`, `OK`, `ERROR`
- Use plain text status indicators instead of emojis
- Replace emoji bullets with ASCII: `-`, `*`, `+`
- Use the four allowed symbols (⚙ ⚠ ✓ ✗) only when semantically appropriate

### Note on This File

This rule file (`language.md`) is excluded from special character checks because it contains examples of prohibited characters for demonstration purposes