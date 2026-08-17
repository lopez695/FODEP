import re

def clean_api_service():
    with open('lib/core/services/rwa_api_service.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove useMockData definition
    content = re.sub(r'\s*this\.useMockData = true,\n', '\n', content)
    content = re.sub(r'\s*final bool useMockData;\n', '\n', content)

    # 2. Extract contents inside if (!useMockData) { ... }
    # Since we can't reliably regex nested braces, we'll do a brace matching pass.
    
    out = []
    i = 0
    in_mock_fallback = False
    
    while i < len(content):
        # Match `if (!useMockData) {`
        if content[i:i+20] == "if (!useMockData) {":
            # Find the matching closing brace
            brace_count = 1
            j = i + 19
            # Skip the 'if (!useMockData) {' part in output
            # We want to unindent the content inside
            inner_start = j
            while j < len(content) and brace_count > 0:
                if content[j] == '{':
                    brace_count += 1
                elif content[j] == '}':
                    brace_count -= 1
                j += 1
            
            inner_end = j - 1
            
            # The inner content:
            inner_content = content[inner_start:inner_end]
            
            # Unindent the inner content by 2 spaces if possible
            lines = inner_content.split('\n')
            unindented_lines = []
            for line in lines:
                if line.startswith('  '):
                    unindented_lines.append(line[2:])
                else:
                    unindented_lines.append(line)
            
            # Remove leading empty newline if exists
            if unindented_lines and unindented_lines[0].strip() == '':
                unindented_lines.pop(0)
                
            out.append('\n'.join(unindented_lines))
            
            # Now we need to skip the fallback logic until the end of the `load: () async {` block or method
            # The fallback logic usually ends with `    },` or `    );` or `  }` for methods like `updateFondsPropres`.
            # Let's search for the next `      },` or `  }` that matches the current indentation level.
            # Actually, looking at the code:
            # return _withDelay(_buildMockDashboard());
            # },
            # We can skip until `\n      },` or `\n    );`
            
            # Let's do this: we mark a flag to skip lines until we see the end of block
            in_mock_fallback = True
            i = j
            continue
            
        if in_mock_fallback:
            # We skip characters until we hit `\n      },` or `\n    );` or `\n  }`
            # Let's peek ahead to see if the current line starts the end of block
            match_end = re.match(r'\n(      \},|    \);|  \})', content[i-1:])
            if match_end:
                in_mock_fallback = False
                # Don't append, let the next loop iteration append the closing brace
            else:
                i += 1
                continue
                
        # Handle `if (useMockData) { ... }` (e.g. in updateFondsPropres)
        if content[i:i+19] == "if (useMockData) {":
            brace_count = 1
            j = i + 18
            while j < len(content) and brace_count > 0:
                if content[j] == '{':
                    brace_count += 1
                elif content[j] == '}':
                    brace_count -= 1
                j += 1
            i = j
            continue

        # Handle massive mock lists
        # _exposures starts at line 227
        if content[i:i+47] == "final List<Map<String, dynamic>> _exposures = [":
            # skip until we see `DashboardSnapshot _buildMockDashboard() {`
            j = content.find("DashboardSnapshot _buildMockDashboard() {", i)
            if j != -1:
                i = j
                continue
            else:
                # If not found, skip to end
                break
                
        # skip DashboardSnapshot _buildMockDashboard() { ... to end of file
        if content[i:i+41] == "DashboardSnapshot _buildMockDashboard() {":
            break

        out.append(content[i])
        i += 1

    # Write back
    with open('lib/core/services/rwa_api_service.dart', 'w', encoding='utf-8') as f:
        f.write("".join(out))

if __name__ == "__main__":
    clean_api_service()
