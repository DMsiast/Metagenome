#!/usr/bin/env Rscript
# Copyright 2016-2019 Yong-Xin Liu <metagenome@126.com>
# Turn off warning
# options(warn = -1) 

# 1. 分析前准备：帮助、参数、依赖包和读取文件

# 命令行运行为当前目录；Rstudio手动运行脚本前需要设置工作目录，使用 Ctrl+Shift+H 或 Session - Set Work Directory - Choose Directory / To Source File Location 设置工作目录


# 1.1 程序功能描述和主要步骤

# 程序功能：绘制物种组成热图
# 主要步骤: 
# - 读取Metaphlan2物种组表 result/metaphlan2/taxonomy.spf(己标准化为100)
# - 物种组成按丰度均值排序
# - 筛选Top N个物种绘制热图

# # 程序使用示例USAGE
# # 显示脚本帮助 help
# Rscript db/script/metaphlan_hclust_boxplot.R -h
# # 默认读取result/metaphlan2/taxonomy.spf，按指定列合并、排序并取Top25种绘制热图，输出至输入目录
# Rscript db/script/metaphlan_hclust_boxplot.R
# # 完整参数：-i输入Metaphlan2文件；
# # -t 分类级别，可选Kingdom/Phylum/Class/Order/Family/Genus/Species/Strain，界门纲目科属种株，推荐门，目，属
# # -n 输出物种数量，默认为25，最大为合并后的数量
# # -o输出图表前缀，默认根据输入文件、物种级别和数量自动生成；
# Rscript db/script/metaphlan_hclust_boxplot.R \
#   -i result/metaphlan2/taxonomy.spf \
#   -t Species \
#   -n 25 \
#   -o result/metaphlan2/boxplot_Species


# 1.2 解析命令行
# 设置清华源加速下载
site="https://mirrors.tuna.tsinghua.edu.cn/CRAN"
# 判断命令行解析是否安装，安装并加载
if (!suppressWarnings(suppressMessages(require("optparse", character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))) {
  install.packages("optparse", repos=site)
  require("optparse",character.only=T) 
}



# 解析参数-h显示帮助信息
# 此版本参数在windows中报错显示3，无法正常运行
if (TRUE){
  option_list = list(
    make_option(c("-i", "--input"), type="character", default="result/kraken2/taxonomy_count.norm.spf", help="Metaphlan2 [default %default]"),
    make_option(c("-t", "--taxonomy"), type="character", default="Species", help="Taxonomy level [default %default]"),
    make_option(c("-n", "--TopN"), type="numeric", default="25", help="Number of taxonomy showing [default %default]"),
    make_option(c("-w", "--width"), type="numeric", default=8,
                help="Width of figure [default %default]"),
    make_option(c("-e", "--height"), type="numeric", default=5,
                help="Height of figure [default %default]"),
    make_option(c("-o", "--output"), type="character", default="", help="Output boxplot filename [default %default]")
  )
  opts = parse_args(OptionParser(option_list=option_list))

  # 调置如果无调设置输出，根据其它参数设置默认输出
  prefix = gsub("taxonomy.spf$", "", opts$input, perl = T)
  if (opts$output==""){opts$output=paste0(prefix, "boxplot", opts$taxonomy, opts$TopN)}

  # 显示输入输出确认是否正确
  # Metaphlan2物种组成表
  print(paste("The input file: ", opts$input,  sep = ""))
  # 绘制的分类级别, 默认为种
  print(paste("Taxonomy level: ", opts$taxonomy, ". Default if Species", sep = ""))
  # 选择绘制高丰度物种数量，默认30，最大为物种级别非冗余条目数量
  print(paste("Number of taxonomy showing: ", opts$TopN,  sep = ""))
  # 输出文件名，不填则为输入目录+boxplot+taxonomy
  print(paste("Output boxplot filename: ", opts$output, sep = ""))
}


# 1.3 安装CRAN来源常用包
# 依赖包列表：参数解析、数据变换、绘图和开发包安装、安装依赖、ggplot主题
package_list = c("ggplot2","dplyr","reshape2")
# 判断R包加载是否成功来决定是否安装后再加载
for(p in package_list){
  if(!suppressWarnings(suppressMessages(require(p, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))){
    install.packages(p, repos=site)
    suppressWarnings(suppressMessages(library(p, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))
  }
}


# 1.4 读取输入文件

# 读取metaphlan2文件
# 默认的quote会跳过2/3的数据，导致行减少产生NA，改默认值为空
taxonomy = read.table(opts$input, header=T, sep="\t", quote = "", row.names=NULL, comment.char="")
print(paste0("All taxonomy annotations are ", dim(taxonomy)[1], " lines!"))
# 去除NA，否则无法计算
taxonomy = na.omit(taxonomy)
# 显示样本总数据，有冗余
# colSums(taxonomy)



# 2. 计算过程

## 2.1 按指定组合并

grp = taxonomy[, opts$taxonomy, drop=F]
abu = taxonomy[,9:dim(taxonomy)[2]]
merge = cbind(abu, grp)
# group_by传变量，前面加".dots="
mergeTax = merge %>% group_by(.dots=opts$taxonomy) %>% summarise_all(sum)
# 合并后表格转换为数据框
mergeTax = as.data.frame(mergeTax)
# 按丰度排序
idx = order(rowMeans(mergeTax[,2:dim(mergeTax)[2]]), decreasing = T)
mergeTax = mergeTax[idx,]
# 添加行名
rownames(mergeTax)=mergeTax[,1]

## 2.1 筛选TopN绘图

# remove rownames line
Top = mergeTax[,-1]
# normalization to percentage 100
Top = as.data.frame(t(t(Top)/colSums(Top,na=T) * 100)) 
# Select TopN line for plotting
Top = head(Top, n=opts$TopN)
Top = cbind(row.names(Top), Top)
colnames(Top)[1] = opts$taxonomy

# melt table
data_all = as.data.frame(melt(Top, id.vars = opts$taxonomy))
# set taxonomy order by abundance, default by alphabet
data_all[[opts$taxonomy]]  = factor(as.character(data_all[[opts$taxonomy]]), levels=rownames(Top))

# 3. 结果输出

# 保存表格
write.table(mergeTax, file=paste(opts$output, ".txt", sep = ""), append = FALSE, sep="\t", quote=F, row.names=F, col.names=T)


# 保存图片
p = ggplot(data_all, aes(x=data_all[[opts$taxonomy]], y = value, fill = data_all[[opts$taxonomy]] )) + 
  geom_boxplot()+ 
  theme(axis.ticks.x = element_blank(), axis.text.x = element_blank())+
  xlab(opts$taxonomy)+ylab("Percentage (%)")+ theme_classic()+
  theme(axis.text.x=element_text(angle=45,vjust=1, hjust=1),legend.position="none")
p = p + geom_jitter(position=position_jitter(0.17), size=1, alpha=0.7)
p
ggsave(paste(opts$output, ".pdf", sep=""), p, width = opts$width, height = opts$height)

