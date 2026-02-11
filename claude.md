# FRP Manager for macOS — 项目规范

## 项目概述

本项目是 [frpmgr](https://github.com/koho/frpmgr) 的 **macOS 原生移植版**，使用 **Apple Swift** 技术栈重新实现。原项目是一个 Windows 平台的 FRP 图形化管理工具，本项目的目标是在 macOS 上提供完全等价的功能体验。

> **参考实现路径**（需配置）：`/Users/LijieZhou/Development/frpmgr`
> 该路径下是原始 Go + Windows walk GUI 实现，所有功能逻辑和交互模式均以此为蓝本。

---

## 技术栈

| 层次 | 技术选型 | 说明 |
|------|---------|------|
| UI 框架 | **SwiftUI** | macOS 13+ (Ventura), 使用原生组件 |
| 应用架构 | **MVVM** | Model-View-ViewModel, 利用 SwiftUI 的 `@Observable` / `@ObservableObject` |
| 进程管理 | **launchd** + `Process` | 替代 Windows Service，使用 launchd plist 管理 frpc 后台进程 |
| IPC 通信 | **Unix Domain Socket** 或 **XPC** | 替代 Windows Named Pipe，GUI 与 frpc 进程间通信 |
| 配置解析 | **Swift TOML/INI 解析** | 兼容 frp 的 TOML 和 INI 配置格式 |
| 打包分发 | **Xcode Project** + `.app` bundle | 支持 DMG/PKG 分发, 可选 notarization |
| 最低系统 | **macOS 13.0 (Ventura)** | 确保 SwiftUI 特性可用 |
| 语言标准 | **Swift 5.9+** | 使用 Swift Concurrency (async/await, actors) |

---

## 原始项目功能全图

以下是从原始 frpmgr 项目提取的 **完整功能清单**，每一项都需要在 macOS 版本中实现等价功能。有几个我必须的要求：
1. 功能完整：所有功能点均需覆盖，无遗漏。
2. 设计简约简单：UI 设计应符合 macOS 原生风格，避免复杂冗余。
3. 必须适配中英文切换。

### 一、应用生命周期

#### 1.1 单实例控制
- **原实现**: Windows Named Mutex（基于可执行路径的 MD5 哈希）
- **macOS 等价**: 使用 `NSRunningApplication` 检测或 `NSDistributedLock`
- **行为**: 如果已有实例运行，激活已有窗口并退出新实例

#### 1.2 启动模式
- **GUI 模式**（默认）: 启动图形界面
- **Service 模式**（`-c <config>`）: 以后台守护进程运行 frpc
  - macOS 上通过 launchd agent/daemon 实现
- **版本查询**（`-v`）: 输出版本号、frp 版本号、构建日期

#### 1.3 密码保护
- 可选的主密码保护，启动时弹出密码验证对话框
- 密码使用安全哈希存储（bcrypt 或 Keychain）
- macOS 实现：使用 `.sheet` modal 或 `NSAlert` 样式的密码输入

#### 1.4 窗口状态持久化
- 记住窗口位置和大小
- macOS 上使用 `@SceneStorage` 或 `UserDefaults` + `NSWindow.setFrameAutosaveName`

---

### 二、主界面结构

主窗口采用 **标签页布局**，包含以下四个标签页：

#### 2.1 配置管理页（Configuration）
这是核心功能页，采用 **左右分栏布局**：

**左侧 — 配置列表 (ConfView)**:
- 单列表格，显示所有配置名称
- 颜色编码：蓝色 = 手动启动（不自动启动）
- 图标指示运行状态：运行中 / 已停止 / 启动中 / 停止中
- 支持拖拽排序
- 支持拖入文件导入配置
- 支持多选删除

**左侧工具栏**:
```
[新建配置 ▼] [删除] [导出]
  ├─ 手动设置（打开编辑对话框）
  ├─ 从文件导入（.ini/.toml/.json/.yml/.yaml/.zip）
  ├─ 从 URL 导入（批量下载）
  └─ 从剪贴板导入（Base64 编码的配置）
```

**左侧右键菜单**:
- 编辑
- 移动（上移 / 下移 / 移到顶部 / 移到底部）
- 打开文件 / 在 Finder 中显示
- 新建配置
- 创建副本（全部 / 仅通用设置）
- 导入配置（文件 / URL / 剪贴板）
- NAT 类型检测
- 复制分享链接（Base64 编码，frp:// scheme）
- 导出全部为 ZIP
- 属性
- 全选
- 删除

**右侧 — 详情面板 (DetailView)**:
包含两个区域：
1. **控制面板 (PanelView)** — 显示运行状态和操控按钮
2. **代理列表 (ProxyView)** — 显示和管理所有代理条目

**未选中时**: 显示欢迎屏幕

---

#### 2.2 日志查看页（Log）

**布局**:
```
[配置选择下拉框] [日期/文件选择下拉框] [打开日志文件夹]
[日志内容表格（单列，显示日志行）]
```

**功能**:
- 选择配置 → 显示该配置的可用日志文件
- 选择日期 → 加载对应日志内容
- "Latest" 选项：显示最新 2000 行，每 5 秒自动刷新
- 文件系统监听 (FSEvents)：日志文件变化时自动更新
- 自动滚动到底部
- 右键菜单：复制 / 全选
- 打开日志文件夹按钮（在 Finder 中打开）

---

#### 2.3 偏好设置页（Preferences）

**区域 1: 主密码**
- 启用/禁用主密码
- 更改密码按钮（弹出对话框，需确认新密码）

**区域 2: 语言**
- 当前语言显示
- 语言选择下拉框（需重启生效）
- 支持语言：English, 简体中文, 繁體中文, 日本語, 한국어, Español

**区域 3: 高级设置**（弹出对话框）
- **通用**: 自动检查更新
- **新配置默认值**:
  - 默认协议（tcp/kcp/quic/websocket/wss）
  - 默认用户
  - 默认日志级别（trace/debug/info/warn/error）
  - 日志保留天数
  - DNS 服务器
  - STUN 服务器
  - 源地址
  - TCP Mux 开关
  - TLS 开关
  - 禁止开机自启
  - 使用旧版文件格式（INI）

---

#### 2.4 关于页（About）

- 应用 Logo
- 版本号
- FRP 版本号
- 构建日期
- "检查更新" / "下载更新" 按钮
- 项目链接、FRP 文档链接
- 当有新版本时，标签页标题显示 "New Version!" 提示

---

### 三、配置编辑对话框 (EditClientDialog)

这是一个包含 **7 个标签页** 的复杂对话框：

#### 3.1 基本 (Basic)
| 字段 | 类型 | 说明 |
|------|------|------|
| 名称 | TextField（必填） | 配置显示名称，不允许重复 |
| 服务器地址 | TextField（必填） | FRP 服务端地址 |
| 服务器端口 | NumberField (0-65535) | 默认 7000 |
| 用户 | TextField | FRP 用户标识 |
| STUN 服务器 | TextField | NAT 穿透 STUN 服务器地址 |

#### 3.2 认证 (Auth)
| 字段 | 类型 | 说明 |
|------|------|------|
| 认证方式 | Dropdown | token / oidc / 无 |
| Token | TextField | 直接输入或从文件读取 |
| Token 来源 | Radio | 直接输入 / 文件 |
| OIDC Client ID | TextField | OIDC 客户端 ID |
| OIDC Client Secret | TextField | OIDC 客户端密钥 |
| OIDC Audience | TextField | OIDC 受众 |
| OIDC Scope | TextField | OIDC 作用域 |
| OIDC Token Endpoint | TextField + 高级按钮 | 高级选项：代理 URL、TLS CA、跳过验证 |
| OIDC 额外参数 | KeyValue 表格 | 自定义 endpoint 参数 |
| 认证范围 | Checkbox × 2 | 心跳认证 / 新连接认证 |

#### 3.3 日志 (Log)
| 字段 | 类型 | 说明 |
|------|------|------|
| 日志级别 | Dropdown | trace/debug/info/warn/error |
| 最大保留天数 | NumberField | 日志文件保留天数 |

#### 3.4 管理 (Admin)
| 字段 | 类型 | 说明 |
|------|------|------|
| 管理地址 | TextField | Admin API 监听地址 |
| 管理端口 | NumberField (0-65535) | Admin API 端口 |
| Admin TLS | Checkbox + 配置按钮 | TLS 证书配置 |
| 管理用户名 | TextField | Admin API 认证 |
| 管理密码 | TextField | Admin API 认证 |
| 资源目录 | BrowsePath | Admin UI 静态资源 |
| 自动删除 | Radio Group | 绝对日期 / 相对天数 / 不删除 |

**自动删除逻辑**:
- **绝对模式**: 到达指定日期后，服务自动卸载并删除配置文件和日志
- **相对模式**: 配置文件最后修改 N 天后自动删除
- **无**: 不自动删除

#### 3.5 连接 (Connection)
| 字段 | 类型 | 说明 |
|------|------|------|
| 协议 | Dropdown | tcp/kcp/quic/websocket/wss |
| 拨号超时 | NumberField (秒) | 连接服务器超时 |
| 保活间隔 | NumberField (秒) | TCP 保活 |
| 连接池大小 | NumberField | 预创建连接数 |
| QUIC 保活周期 | NumberField (秒) | QUIC 协议专用 |
| QUIC 空闲超时 | NumberField (秒) | QUIC 协议专用 |
| QUIC 最大入流 | NumberField | QUIC 协议专用 |
| 心跳间隔 | NumberField (秒) | 客户端心跳 |
| 心跳超时 | NumberField (秒) | 心跳超时 |

**动态 UI**: QUIC 相关字段仅在协议选择 quic 时可见

#### 3.6 TLS
| 字段 | 类型 | 说明 |
|------|------|------|
| 启用 TLS | Toggle | 启用/禁用 |
| 服务器名 | TextField | TLS SNI |
| 证书文件 | BrowseFile | .crt/.pem 文件 |
| 密钥文件 | BrowseFile | .key 文件 |
| CA 文件 | BrowseFile | 信任的 CA 证书 |
| 禁用自定义首字节 | Checkbox | FRP 特有选项 |

#### 3.7 高级 (Advanced)
| 字段 | 类型 | 说明 |
|------|------|------|
| DNS 服务器 | TextField | 自定义 DNS |
| 源地址 | TextField | 绑定本地 IP |
| TCP Mux | Checkbox | TCP 多路复用 |
| TCP Mux 保活间隔 | NumberField (秒) | 仅 TCP Mux 启用时可见 |
| 登录失败后退出 | Checkbox | — |
| 禁止开机自启 | Checkbox | — |
| 使用旧版格式 | Toggle | INI vs TOML |
| 元数据 | KeyValue 表格 | 自定义键值对 |

---

### 四、代理编辑对话框 (EditProxyDialog)

支持 **8 种代理类型**: tcp, udp, xtcp, stcp, sudp, http, https, tcpmux

#### 4.1 头部
| 字段 | 类型 | 说明 |
|------|------|------|
| 代理名称 | TextField + 随机按钮 | 代理标识，可一键生成随机名 |
| 代理类型 | Dropdown | 8 种类型 |
| 注解 | 按钮 → KeyValue 对话框 | 仅 TOML 格式可用 |

#### 4.2 基本 (Basic)
**根据代理类型动态显示不同字段**:

**所有类型通用**:
- 本地地址 (Local Address)
- 本地端口 (Local Port)

**TCP/UDP**:
- 远程端口 (Remote Port)
- 支持端口范围: "6000-6006,6007" 格式（Range Proxy）

**XTCP/STCP/SUDP**:
- 角色: Server / Visitor（Radio 切换）
- 密钥 (Secret Key)
- **Server 模式**: 允许用户列表 (Allow Users)
- **Visitor 模式**: 绑定地址和端口、服务器名称、服务器用户

**HTTP/HTTPS/TCPMUX**:
- 子域名 (Subdomain)
- 自定义域名 (Custom Domains)
- 路由位置 (Locations) — 仅 HTTP
- 多路复用器 (Multiplexer) — 仅 TCPMUX
- 按 HTTP 用户路由 (Route by HTTP User)

#### 4.3 高级 (Advanced)
| 字段 | 类型 | 说明 |
|------|------|------|
| 带宽限制 | Number + 单位(KB/MB) + 模式(Client/Server) | 限速 |
| Proxy Protocol | Dropdown | 自动/v1/v2 |
| 传输协议 | Dropdown | 默认/QUIC/KCP（仅 XTCP visitor） |
| 保持隧道 | Checkbox | XTCP visitor |
| 加密 | Checkbox | 传输加密 |
| 压缩 | Checkbox | 传输压缩 |
| HTTP/2 | Checkbox | HTTP 转发插件 |
| 禁用辅助地址 | Checkbox | XTCP |
| 回退代理 | TextField | XTCP visitor 回退目标 |
| 回退超时 | NumberField (ms) | XTCP visitor |
| 重试次数 | NumberField | 每小时最大重试 |
| 重试间隔 | NumberField (秒) | 最小重试间隔 |
| HTTP 用户/密码 | TextField × 2 | HTTP 认证 |
| Host 重写 | TextField | 修改请求 Host |
| 请求头 | KeyValue 表格 | 自定义 HTTP 请求头 |
| 响应头 | KeyValue 表格 | 自定义 HTTP 响应头 |

#### 4.4 插件 (Plugin)
支持 **9 种插件**:

| 插件 | 专有配置 |
|------|---------|
| http2http | 本地地址, Host 重写, 请求头 |
| http2https | 本地地址, Host 重写, 请求头 |
| https2http | 本地地址, Host 重写, 请求头, TLS 证书/密钥 |
| https2https | 本地地址, Host 重写, 请求头, TLS 证书/密钥 |
| http_proxy | HTTP 用户/密码 |
| socks5 | 用户名/密码 |
| static_file | 本地路径, 路径前缀, HTTP 用户/密码 |
| unix_domain_socket | Unix Socket 路径 |
| tls2raw | 本地地址, TLS 证书/密钥/CA |

#### 4.5 负载均衡 (Load Balance)
| 字段 | 类型 | 说明 |
|------|------|------|
| 分组名称 | TextField | 负载均衡组 |
| 分组密钥 | TextField | 组认证密钥 |

#### 4.6 健康检查 (Health Check)
| 字段 | 类型 | 说明 |
|------|------|------|
| 检查类型 | Dropdown | tcp / http / 无 |
| 检查 URL | TextField | 仅 HTTP 类型 |
| 超时 | NumberField (秒) | — |
| 间隔 | NumberField (秒) | — |
| 最大失败次数 | NumberField | — |

#### 4.7 元数据 (Metadata)
- KeyValue 编辑表格
- 支持添加/删除/清空

---

### 五、代理列表交互 (ProxyView)

#### 5.1 表格列
| 列名 | 说明 |
|------|------|
| 名称 | 带状态图标（运行中/错误/未知）|
| 类型 | tcp/udp/http 等 |
| 本地地址 | — |
| 本地端口 | — |
| 远程端口 | 实际分配端口（可能与请求不同）|
| 域名 | 子域名/自定义域名 |
| 插件 | 插件名称 |
| 远程地址 | 默认隐藏，可切换显示 |

#### 5.2 表格样式
- 禁用的代理：灰色文字
- Visitor 类型代理：蓝色文字
- 运行中的代理：名称列显示状态图标

#### 5.3 工具栏
```
[添加] [快速添加 ▼] [编辑] [禁用/启用] [↑] [↓] [删除]

快速添加菜单（预设模板）:
  ├─ 开放端口 (Open Port) — 自定义端口转发
  ├─ 远程桌面 (Remote Desktop) — VNC: 5900
  ├─ VNC — 端口 5900
  ├─ SSH — 端口 22
  ├─ Web — HTTP 端口 80
  ├─ FTP — 端口 21 + 被动端口范围
  ├─ HTTP 文件服务器 — static_file 插件
  └─ 代理服务器 — http_proxy / socks5 插件
```

#### 5.4 右键菜单
- 编辑
- 禁用 / 启用
- 移动（上/下/顶/底）
- 新建代理
- 快速添加（全部模板）
- 从剪贴板导入
- 显示远程地址（切换）
- 复制访问地址
- 全选
- 删除

#### 5.5 交互行为
- 双击编辑代理
- 拖拽排序
- 启用/禁用单个代理（热重载）
- 复制访问地址到剪贴板
- 从剪贴板导入代理（INI/TOML 片段）
- 运行时实时状态追踪

---

### 六、控制面板 (PanelView)

```
状态:        [图标] 运行中 / 已停止 / 启动中 / 停止中
服务器地址:   [地址文本] [复制图标]
协议:        [协议信息] [🔒 如果启用了加密]
             [启动] 或 [停止] 按钮
```

**交互**:
- 复制服务器地址到剪贴板
- 启动/停止服务（停止时需确认）
- 实时状态更新

---

### 七、属性对话框 (PropertiesDialog)

只读两列表格，显示配置详细信息：

| 属性 | 说明 |
|------|------|
| 配置名称 | — |
| 标识符 | 文件名 |
| 服务名称 | 系统服务标识 |
| 文件格式 | TOML / INI |
| 服务器地址 | — |
| 服务器端口 | — |
| 协议 | — |
| 代理数量 | — |
| 启动方式 | 自动 / 手动 / 无 |
| 日志文件 | 文件数和总大小 |
| TCP/UDP 连接数 | 仅运行时 |
| 进程启动时间 | 仅运行时 |
| 文件创建时间 | — |
| 文件修改时间 | — |

---

### 八、NAT 类型检测对话框

- STUN 服务器地址显示
- 进度条
- 检测结果表格：
  - NAT 类型
  - NAT 行为
  - 本地地址
  - 外部地址（可能多个）
  - 是否公网

---

### 九、URL 导入对话框

- 多行文本输入框（每行一个 URL）
- 状态标签显示下载进度 [N/Total]
- 异步下载，支持取消
- 自动检测 ZIP 文件
- 支持重定向

---

### 十、后台服务管理

#### 10.1 进程生命周期

**原实现**: Windows Service (SCM)
**macOS 等价**: **launchd** (LaunchAgent/LaunchDaemon)

每个配置对应一个独立的 launchd job：
- **标识符**: `com.frpmgr.client.<MD5(configName)>`
- **plist 文件位置**: `~/Library/LaunchAgents/` (用户级)
- **启动参数**: frpc 可执行路径 + `-c <config_path>`
- **自动启动**: `RunAtLoad = true`（非手动模式）
- **手动模式**: `RunAtLoad = false`，仅通过 GUI 启动

**操作映射**:
| 操作 | macOS 实现 |
|------|-----------|
| 安装服务 | 写入 plist + `launchctl load` |
| 卸载服务 | `launchctl unload` + 删除 plist |
| 启动 | `launchctl start <label>` |
| 停止 | `launchctl stop <label>` |
| 查询状态 | `launchctl list <label>` 解析输出 |
| 热重载 | 通过 frpc admin API 发送 reload 请求 |

#### 10.2 状态追踪

**原实现**: Windows Service Change Notifications
**macOS 等价**: 轮询 `launchctl list` 或监控 frpc admin API

状态枚举：
```swift
enum ConfigState {
    case unknown
    case started     // 运行中
    case stopped     // 已停止
    case starting    // 启动中
    case stopping    // 停止中
}

enum ProxyState {
    case unknown
    case running     // 正常运行
    case error       // 出错
}
```

#### 10.3 IPC / 代理状态查询

**原实现**: Windows Named Pipe + GOB 序列化
**macOS 等价**: 通过 **frpc Admin API** (HTTP) 查询代理状态

```
GET http://{adminAddr}:{adminPort}/api/status
```

- 每个运行的配置都有可选的 Admin API
- GUI 定期轮询代理状态并更新 UI
- 支持即时刷新（Probe）

#### 10.4 热重载

**原实现**: Windows `svc.ParamChange` 信号
**macOS 等价**: 调用 frpc Admin API reload 端点

```
GET http://{adminAddr}:{adminPort}/api/reload
```

实现逻辑：
1. 用户修改配置并保存
2. 检测配置变更类型（仅代理变更 vs 通用设置变更）
3. 仅代理变更 → 调用 Admin API reload（热重载）
4. 通用设置变更 → 重启服务（`launchctl stop` + `launchctl start`）

---

### 十一、配置文件管理

#### 11.1 配置格式

支持两种格式：
- **TOML**（默认，现代格式）
- **INI**（旧版格式，兼容性）

#### 11.2 配置文件结构

```
~/Library/Application Support/FRPManager/
├── app.json              # 应用设置（语言、密码、默认值、窗口位置）
├── configs/
│   ├── my-server.toml    # 配置文件
│   ├── office-vpn.ini    # 旧格式配置
│   └── ...
└── logs/
    ├── my-server.log           # 当前日志
    ├── my-server.log.20240101  # 历史日志（按日轮转）
    └── ...
```

#### 11.3 应用配置 (app.json)

```json
{
    "lang": "zh-CN",
    "password": "<bcrypt_hash>",
    "checkUpdate": true,
    "defaults": {
        "protocol": "tcp",
        "user": "",
        "logLevel": "info",
        "logMaxDays": 3,
        "dnsServer": "",
        "natHoleSTUNServer": "stun.easyvoip.com:3478",
        "connectServerLocalIP": "",
        "tcpMux": true,
        "tlsEnable": true,
        "manualStart": false,
        "legacyFormat": false
    },
    "sort": ["my-server", "office-vpn"],
    "position": [100, 200, 800, 600]
}
```

#### 11.4 导入/导出

| 操作 | 支持的来源/目标 |
|------|---------------|
| 从文件导入 | .ini, .toml, .json, .yml, .yaml, .zip |
| 从 URL 导入 | HTTP/HTTPS 下载，自动检测 ZIP |
| 从剪贴板导入 | Base64 编码的配置内容 |
| 导出单个 | 导出配置文件 |
| 导出全部 | ZIP 归档所有配置 |
| 分享链接 | `frp://` scheme + Base64 编码 |

#### 11.5 自动删除机制

```swift
struct AutoDelete {
    var deleteMethod: DeleteMethod    // .absolute / .relative / .none
    var deleteAfterDays: Int          // 相对模式天数
    var deleteAfterDate: Date         // 绝对模式日期
}
```

- 服务启动时检查过期状态
- 过期后：停止服务 → 删除日志 → 删除配置文件 → 卸载 launchd job

---

### 十二、快速添加代理模板

| 模板 | 代理类型 | 默认配置 |
|------|---------|---------|
| 开放端口 | tcp 和/或 udp | 自定义端口，支持选择 TCP/UDP/Both |
| 远程桌面 | tcp | 本地 5900 (macOS Screen Sharing) |
| VNC | tcp | 本地 5900 |
| SSH | tcp | 本地 22 |
| Web | http | 本地 80 |
| FTP | tcp (Range) | 本地 21 + 被动端口范围 |
| HTTP 文件服务器 | tcp + static_file 插件 | 选择本地目录 |
| 代理服务器 | tcp + http_proxy/socks5 插件 | 选择代理类型 |

---

### 十三、国际化 (i18n)

支持 6 种语言：
- English (en-US)
- 简体中文 (zh-CN)
- 繁體中文 (zh-TW)
- 日本語 (ja-JP)
- 한국어 (ko-KR)
- Español (es-ES)

**macOS 实现**: 使用 `String(localized:)` + `.strings` / `.stringsdict` 文件或 `String Catalogs (.xcstrings)`

---

### 十四、版本更新检查

- 调用 GitHub API: `https://api.github.com/repos/<owner>/<repo>/releases/latest`
- 比较版本号
- 有新版本时在 About 标签页显示提示
- 提供下载链接

---

## macOS 架构映射

### 项目结构建议

```
FRPManager/
├── FRPManager.xcodeproj
├── FRPManager/
│   ├── App/
│   │   ├── FRPManagerApp.swift          # @main 入口
│   │   └── AppDelegate.swift            # 生命周期管理
│   ├── Models/
│   │   ├── ClientConfig.swift           # FRP 客户端配置模型
│   │   ├── Proxy.swift                  # 代理配置模型
│   │   ├── AppConfig.swift              # 应用设置模型
│   │   └── AutoDelete.swift             # 自动删除模型
│   ├── ViewModels/
│   │   ├── ConfigListViewModel.swift    # 配置列表 VM
│   │   ├── ProxyListViewModel.swift     # 代理列表 VM
│   │   ├── LogViewModel.swift           # 日志查看 VM
│   │   └── PreferencesViewModel.swift   # 偏好设置 VM
│   ├── Views/
│   │   ├── MainWindow.swift             # 主窗口 TabView
│   │   ├── ConfigPage/
│   │   │   ├── ConfigPageView.swift     # 配置管理页
│   │   │   ├── ConfigListView.swift     # 左侧配置列表
│   │   │   ├── DetailView.swift         # 右侧详情
│   │   │   ├── PanelView.swift          # 控制面板
│   │   │   └── ProxyTableView.swift     # 代理表格
│   │   ├── Dialogs/
│   │   │   ├── EditClientDialog.swift   # 配置编辑对话框
│   │   │   ├── EditProxyDialog.swift    # 代理编辑对话框
│   │   │   ├── PropertiesDialog.swift   # 属性对话框
│   │   │   ├── NATDiscoveryDialog.swift # NAT 检测
│   │   │   ├── URLImportDialog.swift    # URL 导入
│   │   │   └── QuickAdd/               # 快速添加对话框
│   │   ├── LogPage/
│   │   │   └── LogPageView.swift        # 日志查看页
│   │   ├── PreferencesPage/
│   │   │   └── PreferencesView.swift    # 偏好设置页
│   │   ├── AboutPage/
│   │   │   └── AboutView.swift          # 关于页
│   │   └── Components/
│   │       ├── BrowseField.swift        # 文件选择组件
│   │       ├── KeyValueEditor.swift     # 键值对编辑器
│   │       └── ListEditor.swift         # 列表编辑器
│   ├── Services/
│   │   ├── LaunchdManager.swift         # launchd 进程管理
│   │   ├── FRPCBridge.swift             # frpc 进程交互
│   │   ├── ConfigFileManager.swift      # 配置文件读写
│   │   ├── StatusTracker.swift          # 状态监控
│   │   ├── UpdateChecker.swift          # 版本更新
│   │   └── ImportExportManager.swift    # 导入导出
│   ├── Config/
│   │   ├── TOMLParser.swift             # TOML 解析
│   │   ├── INIParser.swift              # INI 解析
│   │   └── ConfigConverter.swift        # 格式转换
│   ├── Utilities/
│   │   ├── FileUtils.swift              # 文件操作
│   │   ├── StringUtils.swift            # 字符串工具
│   │   └── NetworkUtils.swift           # 网络工具
│   ├── Resources/
│   │   ├── Assets.xcassets              # 图标和图片
│   │   └── Localizable.xcstrings        # 多语言字符串
│   └── Info.plist
├── FRPManagerTests/
│   └── ...
└── README.md
```

### 关键技术映射

| 原实现 (Windows/Go) | macOS/Swift 等价 |
|---------------------|-----------------|
| lxn/walk GUI | SwiftUI |
| Windows Service (SCM) | launchd (LaunchAgent) |
| Named Pipe IPC | frpc Admin HTTP API / Unix Domain Socket |
| Windows Service Notifications | 轮询 launchctl 或 Process 监控 |
| gopkg.in/ini.v1 | 自实现 INI Parser 或使用 Swift 库 |
| pelletier/go-toml | 使用 swift-toml 或类似库 |
| walk.DataBinder | SwiftUI `@Binding` / `@Observable` |
| Windows MessageBox | `NSAlert` / `.alert` modifier |
| 文件对话框 | `NSOpenPanel` / `.fileImporter` |
| Windows 注册表 | `UserDefaults` / `app.json` |
| .ico 图标 | SF Symbols + .xcassets |
| fsnotify | `DispatchSource.makeFileSystemObjectSource` 或 FSEvents |
| go-winio | Foundation `FileHandle` / `Process` |
| GOB 序列化 | `Codable` (JSON) |
| context.Context | Swift `Task` cancellation |
| sync.Mutex | Swift `actor` 或 `os_unfair_lock` |
| goroutine | Swift `Task` / `async` |

---

## 开发原则

1. **功能对等**: 每一个原版功能都必须有 macOS 等价实现，不遗漏
2. **原生体验**: 遵循 macOS HIG（Human Interface Guidelines），使用原生控件和交互模式
3. **Swift 惯用法**: 使用 Swift Concurrency、Codable、Property Wrappers 等现代特性
4. **最小依赖**: 优先使用系统框架，仅在必要时引入第三方库
5. **安全性**: 密码存储使用 Keychain，敏感配置加密存储
6. **可打包**: 项目必须可以直接通过 Xcode 构建为 .app bundle，并支持 DMG/PKG 分发

---

## frpc 二进制集成

macOS 版本需要集成 frpc 客户端二进制：

**方案 A（推荐）**: 将 frpc 编译为 macOS 二进制，嵌入 .app bundle 的 `Contents/Resources/` 或 `Contents/MacOS/` 目录

**方案 B**: 使用 frp 的 Go 库通过 CGo 桥接（复杂度高，不推荐）

**方案 C**: 要求用户自行安装 frpc，应用从 PATH 或指定路径查找

推荐方案 A，从 frp 项目为 macOS (arm64/amd64) 编译 frpc，作为 universal binary 嵌入。

---

## 常量参考

```swift
// 支持的协议
let protocols = ["tcp", "kcp", "quic", "websocket", "wss"]

// 代理类型
let proxyTypes = ["tcp", "udp", "xtcp", "stcp", "sudp", "http", "https", "tcpmux"]

// 插件类型
let pluginTypes = [
    "http2http", "http2https", "https2http", "https2https",
    "http_proxy", "socks5", "static_file", "unix_domain_socket", "tls2raw"
]

// 认证方式
let authMethods = ["token", "oidc"]

// 删除模式
let deleteMethods = ["absolute", "relative"]

// 日志级别
let logLevels = ["trace", "debug", "info", "warn", "error"]

// 默认 STUN 服务器
let defaultSTUNServer = "stun.easyvoip.com:3478"

// 默认服务器端口
let defaultServerPort = 7000
```

---

## 参考文件索引

在实现具体功能时，可参考原始仓库中的对应文件：

| 功能模块 | 参考文件路径 |
|---------|------------|
| 配置数据模型 | `pkg/config/client.go` (688 行) |
| 格式转换逻辑 | `pkg/config/conversion.go` (761 行) |
| 应用设置 | `pkg/config/app.go` (77 行) |
| 自动删除 | `pkg/config/conf.go` (65 行) |
| V1 配置包装 | `pkg/config/v1.go` (72 行) |
| 服务生命周期 | `services/service.go` (156 行) |
| FRP 客户端封装 | `services/client.go` (126 行) |
| 服务安装/卸载 | `services/install.go` (143 行) |
| 状态追踪 | `services/tracker.go` (172 行) |
| IPC 服务端 | `pkg/ipc/server.go` (66 行) |
| IPC 客户端 | `pkg/ipc/pipe.go` (80 行) |
| 主窗口 | `ui/ui.go` (243 行) |
| 配置列表视图 | `ui/confview.go` |
| 配置编辑对话框 | `ui/editclient.go` |
| 代理编辑对话框 | `ui/editproxy.go` |
| 代理列表视图 | `ui/proxyview.go` |
| 控制面板 | `ui/panelview.go` |
| 日志页面 | `ui/logpage.go` |
| 偏好设置页 | `ui/prefpage.go` |
| 快速添加 | `ui/quickadd.go`, `ui/portproxy.go`, `ui/simpleproxy.go`, `ui/pluginproxy.go` |
| 可复用组件 | `ui/composite.go` |
| 数据模型 | `ui/model.go` |
| 属性对话框 | `ui/properties.go` |
| NAT 检测 | `ui/nathole.go` |
| URL 导入 | `ui/urlimport.go` |
| 常量定义 | `pkg/consts/config.go`, `pkg/consts/state.go` |
| 工具函数 | `pkg/util/misc.go`, `pkg/util/file.go`, `pkg/util/strings.go` |
| 资源定义 | `pkg/res/res.go` |
| 国际化 | `i18n/text.go`, `i18n/locales/` |
