# sta

一个随手搓的小脚本，用来控制`./state/self.md`的状态属性控制。

**注意，改脚本是基于git日志记录的，请不要随意改变日志和`.gitignore`的内容。**

属性格式是`属性介绍 属性名：属性值`。有简单的两层结构。用`**`加粗的是一级属性，下面的是二级属性。

比如：
```
**生命值 HP**：100  
饥饿值 HG：30  
**精神值 MP**：70  
```

属性值可以通过`git_tools.sh`修改。当然可以起别名，在任意目录下都可以使用。

```
alias sta='/your/path/git_tools.sh'
sta [commit|merge|ls|set|mfy|add|del|show]
```
- `commit` 保存属性，并提交git
- `merge [day|month day|year month day]` 合并指定日期的所有提交，并合并到日期对应的位置，为md文件。默认当日
- `ls [attribute]` 展示目前的属性值
- `set <attribute> <value>` 设置属性值
- `mfy <状态名称> <状态值>` 修改属性值
- `add <状态名称> <状态描述> <状态值> [状态类型]` 新添加属性值，类别是上一级属性的名称
- `del <状态名称>` 删除属性
- `show [-d [[yyyy-]mm-]dd] [-f ...] [-a]` 利用python对属性变化的可视化


## 环境

- Linux
- python3
- git
