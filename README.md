# vscode-profiles

此仓库维护了一套用于 Visual Studio Code 的 Profile 配置文件集合，旨在为不同的开发场景（如前端、Go 后端、AWS 开发、GCP 开发）提供标准化且隔离的开发环境。

## 🛠️ Profiles 概览

| Profile | 适用场景 | 核心工具/MCP 支持 |
| :--- | :--- | :--- |
| **`aws-node`** | AWS 前端开发 | AWS (CloudFormation), Biome |
| **`aws-go`** | AWS Go 后端开发 | AWS (Full Suite), Go, Prettier |
| **`node`** | 通用/GCP 前端开发 | GCP, Biome |
| **`go`** | 通用/GCP Go 后端开发 | GCP, Go, PostgreSQL, Prettier |
| **`swift`** | Swift 开发 | Swift, GitHub Actions, Context7 |
| **`default`** | 默认/通用环境 | GCP, 通用配置, Prettier |

## 📂 配置文件说明

每个 Profile 目录都包含以下标准配置文件，您可以直接将其内容导入到 VS Code Profile 中：

- **`settings.json`**: 编辑器偏好设置（格式化行为、字体、语言特定配置等）。
- **`extensions.json`**: 该场景推荐的扩展列表。切换 Profile 后，VS Code 会提示您安装。
- **`mcp.json`**: AI 助手（如 Claude, Gemini）所需的 MCP 服务器配置。

### 项目本地配置

项目根目录下的 `.vscode` 文件夹包含了开发本项目时的 VS Code 配置：

- **`settings.json`**: 配置 Biome 作为默认格式化工具，保存时自动格式化
- **`extensions.json`**: 推荐安装 Biome 扩展
- **`launch.json`**: Node.js 调试配置

## 🔍 扩展一致性检查 (快捷命令)

以下是各 Profile 的一致性检查命令，您可以直接复制运行。命令顺序依次为：**检查多余**（装了但没记）、**检查缺失**（记了但没装）、**同步回 JSON**。

### Default (默认)

```bash
comm -23 <(code --list-extensions --profile Default | sort) <(jq -r '.[]' config/default/extensions.json | sort)
comm -13 <(code --list-extensions --profile Default | sort) <(jq -r '.[]' config/default/extensions.json | sort)
code --list-extensions --profile Default | jq -R . | jq -s . > config/default/extensions.json
```

### aws-node

```bash
comm -23 <(code --list-extensions --profile aws-node | sort) <(jq -r '.[]' config/aws-node/extensions.json | sort)
comm -13 <(code --list-extensions --profile aws-node | sort) <(jq -r '.[]' config/aws-node/extensions.json | sort)
code --list-extensions --profile aws-node | jq -R . | jq -s . > config/aws-node/extensions.json
```

### aws-go

```bash
comm -23 <(code --list-extensions --profile aws-go | sort) <(jq -r '.[]' config/aws-go/extensions.json | sort)
comm -13 <(code --list-extensions --profile aws-go | sort) <(jq -r '.[]' config/aws-go/extensions.json | sort)
code --list-extensions --profile aws-go | jq -R . | jq -s . > config/aws-go/extensions.json
```

### node

```bash
comm -23 <(code --list-extensions --profile node | sort) <(jq -r '.[]' config/node/extensions.json | sort)
comm -13 <(code --list-extensions --profile node | sort) <(jq -r '.[]' config/node/extensions.json | sort)
code --list-extensions --profile node | jq -R . | jq -s . > config/node/extensions.json
```

### go

```bash
comm -23 <(code --list-extensions --profile go | sort) <(jq -r '.[]' config/go/extensions.json | sort)
comm -13 <(code --list-extensions --profile go | sort) <(jq -r '.[]' config/go/extensions.json | sort)
code --list-extensions --profile go | jq -R . | jq -s . > config/go/extensions.json
```

### swift

```bash
comm -23 <(code --list-extensions --profile swift | sort) <(jq -r '.[]' config/swift/extensions.json | sort)
comm -13 <(code --list-extensions --profile swift | sort) <(jq -r '.[]' config/swift/extensions.json | sort)
code --list-extensions --profile swift | jq -R . | jq -s . > config/swift/extensions.json
```
