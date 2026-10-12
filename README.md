# Cloudline Godot 0.2.0 preview

Cloudline 的独立 Godot 手机试玩版。保留原有 PortFWeb / Cloudline 在线版，不改动旧站点。

- Godot 4.6.3，Compatibility 渲染器，单线程 Web 导出
- A320 已接入真实 GLB 模型与贴图（amvlab，CC BY 4.0）；L-4/J-120 及机场仍为简化模型
- 模型来源、修改说明和许可：[MODEL-CREDITS.txt](cloudline-godot/MODEL-CREDITS.txt)
- Godot 工程：`godot-cloudline/project.godot`
- 网页导出：`cloudline-godot/`
- GitHub Pages 工作流只发布网页导出目录

## 试玩范围与验证边界

本版包含原生飞行、任务航线、触控界面、PFD/小地图、引导圈、昼夜/天气设置与音效接入。飞行与机场均为游戏近似，不用于真实飞行训练。

原生图形和操作已在云电脑验证；最终源码和导出文件的 SHA-256 清单在 `cloudline-godot/release-manifest.json`。浏览器 WebGL、手机真机帧率/触控与实际扬声器听感尚未验证。原生通过不代表手机兼容性通过。

更完整的玩法、操作、验证结果与已知限制见 [Godot 工程说明](godot-cloudline/README.md)。

## 发布构建

为避免单个大型 WebAssembly 文件的上传限制，仓库保存官方 Godot Web 引擎的 gzip 文件。GitHub Actions 使用 Python 标准库校验压缩文件 SHA-256，解压并校验原始 WASM 的大小和 SHA-256，再逐个核对已评审源码与导出文件，最后发布到 GitHub Pages。

```sh
python3 godot-cloudline/web-build/test_assembly.py
python3 godot-cloudline/web-build/assemble_wasm.py
python3 godot-cloudline/web-build/verify_release.py
```

这一步只还原原始引擎文件，不修改游戏源码、PCK 或浏览器加载器。部署工作流不会重新编译 Godot 游戏；游戏更新需要重新导出并更新校验清单。

Godot 引擎与字体的版权/许可说明随工程和网页导出一同提供。本仓库未替游戏项目新增开源许可授权。
