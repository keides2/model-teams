#!/bin/bash

# cron のカレントは、/home/vuls/
cd /home/vuls/model

# model フォルダ
MODEL_FOLDER="/mnt/z/model/"

# Teams 投稿先 新機種名情報＞コネクタ NewModel 
MODEL_URL="https://outlook.office.com/webhook/xxxxx/IncomingWebhook/yyyyy/zzzzz"

# Teams タイトル
TITLE="model-新機種名情報"

# 1番新しいファイル model_aray[1] から機種名のみを抽出したファイル
LATEST1_FILE="latest1.txt"
# 2番目に新しいファイル model_aray[0] から機種名のみを抽出したファイル
LATEST2_FILE="latest2.txt"

# 差分結果の通知用ファイル（あとで LATEST_DATE を付ける diff_result-20201109.txt）
DIFF_RESULT="diff_result"
# 差分結果ファイル（暫定）
DIFF_RESULT_FILE="${DIFF_RESULT}.txt"
# 差分結果ファイル（Zドライブ保存用）
DIFF_RESULT_Z_FILE=""

# 機種名と生産予定日の列番号
MODEL_COLUMN=8
MP_COLUMN=16

# 最新2つのファイルリスト作成
model_files=$(ls -rt ${MODEL_FOLDER}*model.csv | tail -n 2)
echo "● model_files:"
echo -e "${model_files}\n"

# 配列の宣言
declare -a model_aray=()

# ファイル名を取り出し、配列に入れる
# パイプを使うとその時点でサブシェルができて、変数のスコープがサブシェルに行くので、while文の外で変数が使えない
# よって、パイプを使わない
i=0
while read line
do
    # echo $i, $line

    # ファイル名からフォルダー名を削除
    line=${line##*/}    # 左端から最長除外
    model_aray[$i]=$line
    echo $i, ${model_aray[$i]}
    i=$(($i + 1))
done << EOF
${model_files}
EOF

echo -n -e "\n"

# CSV ファイルから、機種名と生産予定日の列を取り出しファイルに保存
cut -d ',' -f ${MODEL_COLUMN},${MP_COLUMN} ${MODEL_FOLDER}${model_aray[0]} > ${LATEST2_FILE}
cut -d ',' -f ${MODEL_COLUMN},${MP_COLUMN} ${MODEL_FOLDER}${model_aray[1]} > ${LATEST1_FILE}

# 1番新しいファイル名の先頭8文字（＝日付）
LATEST_DATE=${model_aray[1]:0:8}

# 結果の保存先ファイル名作成
DIFF_RESULT_Z_FILE=${DIFF_RESULT}"-"${LATEST_DATE}".txt"
echo "● 結果の保存先ファイル： ${DIFF_RESULT_Z_FILE}"

# 更新日
UPDATE_DATE=`date -d ${LATEST_DATE} "+%Y年%m月%d日"`

# model機種情報ファイル作成
echo "" > ${DIFF_RESULT_Z_FILE}
{
    echo "\\n\\n■以下のファイルから機種名と生産予定日の差分を抽出しました"
    echo "\\n\\n- １番新しいmodel機種情報ファイル：${model_aray[1]}"
    echo "\\n\\n- ２番目に新しいmodel機種情報ファイル：${model_aray[0]}"
    echo "\\n\\n"
} >> ${DIFF_RESULT_Z_FILE}

echo -n -e "\n"

# 差分取得 - 追加、削除、変更
# 差分結果を保存（暫定）
diff -c ${LATEST2_FILE} ${LATEST1_FILE} > ${DIFF_RESULT_FILE}

if [ $? -eq 0 ]; then
    # 変更なし

    # 同一ファイル
    echo "\\n\\n■変更はありませんでした" >> ${DIFF_RESULT_Z_FILE}

elif [ $? -eq 1 ]; then
    # 変更あり

    # 変更の数
    # 追加された機種数あるいは生産予定日カウント
    {
        echo -n "\\n\\n■追加された機種数あるいは生産予定日の数："
        A_COUNT=$(grep -c '^+ ' ${DIFF_RESULT_FILE})
        echo $((A_COUNT))
        echo "\\n\\n"
    } >> ${DIFF_RESULT_Z_FILE}

    # 削除された機種数あるいは生産予定日カウント
    {
        echo -n "\\n\\n■削除された機種数あるいは生産予定日の数："
        D_COUNT=$(grep -c '^- ' ${DIFF_RESULT_FILE})
        echo $((D_COUNT))
        echo "\\n\\n"
    } >> ${DIFF_RESULT_Z_FILE}

    # 変更された機種数あるいは生産予定日カウント
    {
        echo -n "\\n\\n■変更された機種数あるいは生産予定日の数："
        M_COUNT=$(grep -c '^! ' ${DIFF_RESULT_FILE})
        M_COUNT=$((M_COUNT/2))
        echo $((M_COUNT))
        echo "\\n\\n"
        echo "\\n\\n"
    } >> ${DIFF_RESULT_Z_FILE}

    # 機種名と生産予定日
    # 追加された機種名と生産予定日
    {
        echo "\\n\\n■追加された機種名と生産予定日："
        echo "\\n\\n　機種名,生産予定日"
        grep '^+ \"' ${DIFF_RESULT_FILE} | sed 's/^+ /\\n\\n- /g'
        echo "\\n\\n"
    } >> ${DIFF_RESULT_Z_FILE}

    # 合計
    TOTAL_COUNT=$((A_COUNT+D_COUNT+M_COUNT))
    echo Total:$((TOTAL_COUNT))

    # あるとき
    if [ $((D_COUNT)) -ne 0 ]; then
        # 削除された機種名と生産予定日
        {
            echo "\\n\\n■削除された機種名と生産予定日："
            echo "\\n\\n　機種名,生産予定日"
            grep '^- \"' ${DIFF_RESULT_FILE} | sed 's/^- /\\n\\n- /g'
            echo "\\n\\n"
        } >> ${DIFF_RESULT_Z_FILE}
    fi

    # あるとき
    if [ $((M_COUNT)) -ne 0 ]; then
        # 変更された機種名と生産予定日
        {
            echo "\\n\\n■変更された機種名と生産予定日："
            echo "\\n\\n　機種名,生産予定日"
            grep '^! \"' ${DIFF_RESULT_FILE} | sed 's/^! /\\n\\n- /g'
            echo "\\n\\n"
        } >> ${DIFF_RESULT_Z_FILE}
    fi

else
    # エラー
    echo "\\n\\n■diffエラーが発生しました" >> ${DIFF_RESULT_Z_FILE}
fi

# Teams 投稿用ファイルの作成
# -e 付けない（エスケープを解釈しない）、-n 最後の改行を出力しない
# echo -n "{\"title\": \"$TITLE（${UPDATE_DATE}）\", \"text\": \"- 機種名,生産予定日" > toTeams.json
# {"title": "model-新機種情報（20201116）test", "text": "- 機種名,生産予定日

echo -n "{\"title\": \"$TITLE（${UPDATE_DATE}）\", \"text\": \"" > toTeams.json
# {"title": "model-新機種情報（20201116）", "text": 

# 追加・変更・削除の合計が多いときはメッセージ
if [ $((TOTAL_COUNT)) -gt 150 ]; then
    # 多すぎます
    echo -n "※追加／削除／変更件数が多すぎるためここに表示できません。\n\nZドライブのファイル（ [Z:/model/done/$DIFF_RESULT_Z_FILE](Z:/model/done/$DIFF_RESULT_Z_FILE) ）を確認してください"。 >> toTeams.json
else
    # 整形
    sed -e 's/\"\,\"/\,/g' -e 's/\"//g' ${DIFF_RESULT_Z_FILE} | tr -d "\n" >> toTeams.json
fi

# } 閉じ
echo "\"}" >> toTeams.json
# {"title": "model-新機種情報（20201116）", "text": "\n\n■以下のファイルから（中略）\n\n- AN22Y,2021/02/23\n\n"}

# 結果ファイル１の確認
echo -n -e "\n"
echo "--- 結果ファイル１の表示 ---"
cat ${DIFF_RESULT_Z_FILE}

# 結果ファイル２の確認
echo -n -e "\n"
echo "--- 結果ファイル２の表示 ---"
cat toTeams.json

# Teamsへ投稿
echo "Teams へ投稿します"
echo -n "Curl result: "
curl -x proxy.abcd.com:3128 -H "Accept: application/json" -H "Content-type: application/json" -X POST \
	 -d @toTeams.json ${MODEL_URL}
#	 -d '{"title": "'$TITLE'", "text": "- Date='$LATEST_DATE'\n\n- 新機種名='FK25V'\n\n- 生産予定日='2021年2月21日'"}' ${MODEL_URL}

echo -n -e "\n"

# 投稿に成功すると '1' が帰ってくる
# echo "Curl result '1' means success."

# 結果ファイル１の '\n\n- ' を削除して、Zドライブに移動
sed -i -e 's/^\\n\\n//g' -e 's/^- //g' ${DIFF_RESULT_Z_FILE}
mv ${DIFF_RESULT_Z_FILE} ${MODEL_FOLDER}done/

echo "All done!"
