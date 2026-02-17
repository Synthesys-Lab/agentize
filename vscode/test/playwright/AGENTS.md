This is the folder for playwright-based frontend testing.
Each test should follow:
1. Name it as `test_x.js/ts` where `x` is the name of the feature being tested.
2. Each test is soft, which means they are not run automatically. You need to run them manually,
   as determining the expected output is subjective, and may require your intelligence.
3. Each test should be self-contained, meaning it should setup its own environment and clean up after itself.
4. Each test should have a unified harness maintaining a single source of truth with the VSCode extension's
   real render and behavior.
5. Each test case should dump to `.tmp/x-y.png` where `x` is the name of the test, and `y` the step of the case.
6. Each test case should have a clear description of what it is testing and the expected outcome
   in a separate markdown file named `test_x.md` where `x` is the name of the test. This file should include:
    - A brief overview of the feature being tested.
    - A step-by-step description of the test case, including the actions taken and the expected results at each step.
