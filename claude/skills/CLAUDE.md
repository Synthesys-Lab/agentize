# Write a skill

- When asked to write a skill, focus on the skill itself, while adhering to the whole workflow as described in the root `README.md` and `docs/*.md`.
  - **DO NOT** include anything:
    - further skills' development ideas
    - improvements to the overall workflow
    - post-skill steps
  - Skills are something like "leaves" on a tree, which does the most specific actions.
    - Skills **CANNOT** invoke other skills, agents, or commands.
    - Skills **CAN** define a series of steps using commandline tools, and doing simple conditional logics (but not loops).
- Ownership/authorship claim is **ONLY** reflected for the `commit-msg` skill, other skills **SHALL NOT** have any ownership claim.
- Few-shot examples are encouraged to be a part of skill, but do not overdo it.
  - If you have concrete big examples that consumes multiple (~10) lines, at most 3 examples: 2 positive and 1 negative, are recommended.
  - If examples are as simple as 1-2 lines, you can add up to 5 examples for both positive and negative.
- **DO NOT** over-engineer the troubleshooting or error handling, just cast errors to users for help. It is safe to assume:
  - `git`, `gh`, `make` and other common tools are always available and working properly.
  - This repo is faithfully cloned and initialized so each commited folder/file exists as expected.
- Read `https://agentskills.io/` for more guidelines on writing skills, when:
    - You want to refer a file within the scope of the skill.
    - You want to use a script within the scope of the skill.
