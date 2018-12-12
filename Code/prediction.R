setwd("/home/pgbook/FinalProject/BigDataFinalProject/Code/")
#install.packages("randomForest")
library("ROCR")
library("gplots")
library("caret")
library("e1071")
library("RSQLite")
library("randomForest")
library("dplyr")
library("ggplot2")
# connect to the sqlite file
sqlite.driver <- dbDriver("SQLite")
db = dbConnect(drv=sqlite.driver, dbname="./../SQL/Bugs.db")
dbfeature = dbConnect(drv=sqlite.driver, dbname="./../SQL/features.db")

#seed
set.seed(162534)

alltables = dbListTables(dbfeature)
alltables


set <- dbGetQuery(dbfeature,
                  ' 
                  SELECT *
                  FROM MasterTable
;
                  ')
set
head(set)
#create partitioning 70%triningsdata 30% validation
trainIndex1=createDataPartition(set$target,p=0.7)$Resample1
train1=set[trainIndex1, ]
test1=set[-trainIndex1, ]

trainIndex=createDataPartition(train1$target,p=0.7)$Resample1
train=set[trainIndex, ]
test=set[-trainIndex, ]
#makeClassifier
colnames(train)
colnames(train)[-which(colnames(train) %in% c("target","id"))]
featurelist<-colnames(train)[-which(colnames(train) %in% c("target","id"))]
#df<-data.frame(auc=numeric(10000), mod = character(10000), stringsAsFactors = FALSE)
length(featurelist)
featurelist<-c("numStatusUpdates","rateLastAssignee","rateFirstAssignee","rateLastAssigner","rateFirstAssigner",
               "rateReporter","month","Length","ageSoftwareVersionInDays","teamWorkRate","year",
               "numCC")

df = NULL
tries = 200
for (i in 1:tries){
  sample<-sample(featurelist, sample(1:length(featurelist), 1))
  #form<-(paste0("target~",paste0("", sample, collapse="+"),""))
  form<-(paste0("as.factor(target)~",paste0("", sample, collapse="+"),""))
  formula<-as.formula(form)
  
  print(formula)
  NB_model <- naiveBayes(formula,data=train,laplace = 0)
  trainPred <- predict(NB_model, test[,-which(names(test) %in% c("target"))])
  trainPred
  prediction <- prediction(as.numeric(trainPred),test$target)
  ROC<-performance(prediction,"tpr","fpr")
  auc<-performance(prediction,measure = "auc")
  print(auc@y.values)
  df = rbind(df, data.frame(as.numeric(auc@y.values),form))
}
# for (j in 1:length(featurelist)){
#   print(j)
#   res<-combn(featurelist,j)
#   comblist <- list()
#   for (i in 1:(length(res)/j)){
#     print(i)
#     #comblist[[i]]<-(paste0("as.factor(target)~",paste0("as.factor(", res[,i],")", collapse="+"),""))
#     comblist[[i]]<-(paste0("as.factor(Target)~",paste0("", res[,i], collapse="+"),""))
#     #comblist[[i]]<-(paste0("target~",paste0("as.factor(", res[,i],")", collapse="+"),""))
#     
#   }
#   for (i in 1:length(comblist)) {
#     print(comblist[[i]])
#     form<-as.formula(comblist[[i]])
#     NB_model <- naiveBayes(form,data=train)
#     #SVM_model <- svm(as.factor(target)~SuccessRateAssignee,data=train)
#     #SVM_model <- svm(form,data=train)
#     trainPred <- predict(NB_model, test[,-which(names(test) %in% c("Target"))])
#     trainPred
#     prediction <- prediction(as.numeric(trainPred),test$Target)
#     ROC<-performance(prediction,"tpr","fpr")
#     auc<-performance(prediction,measure = "auc")
#     print(auc@y.values)
#     df = rbind(df, data.frame(as.numeric(auc@y.values),comblist[[i]]))
#     #n<-nrow(na.omit(df))
#     #df$auc[n+1] <- as.numeric(auc@y.values)
#     #df$mod[n+1] <- comblist[[i]]
#     
#   }
# }
print("**************************")
df
head(df[order(-df$as.numeric.auc.y.values.),])
#png(filename = "rocr.png",width=700, height = 700)
#plot(x,col=6)
#dev.off()

