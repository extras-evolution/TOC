<?php

/**
 * @name TOC
 * @version 0.9.1b, 15 august 2009
 * @desc Плагин для автоматического создания оглавления на странице с помощью якорей.
 * 
 * @author Максим Мухарев (Carw)
 * @license GNU General Public License
 * 
 * Инструкция:
 * 
 * Создайте новый плагин с именем TOC и с копируйте в него данный код.
 * 
 * Привяжите плагин к системному событию OnLoadWebDocument.
 * 
 * В параметры добавьте следующую информацию:
 * &lStart=Начальный уровень;list;1,2,3,4,5,6;2 &lEnd=Конечный уровень;list;1,2,3,4,5,6;3 &table_name=Транслитерация;list;common,russian;russian &tocTitle=Название;string;Содержание &tocClass=CSS-класс;string;toc &tocAnchorType=Тип якоря;list;1,2;1 &tocAnchorLen=Максимальная длина якоря;number;0
 * 
 * Имеющиеся параметры:
 * 
 * Начальный уровень - начальный уровень заголовка (H1 - H6)
 * Конечный уровень - конечный уровень заголовка (H1 - H6)
 * Транслитерация - будет использоваться для первого типа якорей. Используются таблицы плагина TransAlias.
 * Название - заголовок для оглавления. Если поле пустое, то заголовок игнорируется.
 * CSS-класс - класс стиля, который будет использоваться в оглавлении (контейнер и вложенные уровни)
 * Тип якоря - разные вариант генерации названия якоря. 1 - транслит, 2 - нумерация
 * Максимальная длина якоря - используется при транслитерации и ограничивает длину названия якоря
 * 
 * Использование:
 * 
 * После генерации оглавление помещается в глобальный плейсхолдер [+toc+]. Поэтому для вывода достаточно поместить его в соответствующее место.
 * 
 * Нюансы:
 * 
 * - сильные перепады в уровнях вложенности (например H1 - H3) вставляют лишние закрывающие теги
 * - оглавление кешируется, но при это не учитывает динамически добавленных заголовков. 
 * - оглавление создается во всех шаблонах, даже там где не используется
 */

global $modx;

$lStart = isset($lStart) ? $lStart : 2;
$lEnd = isset($lEnd) ? $lEnd : 3;
$tocTitle = isset($tocTitle) ? $tocTitle : '';
$tocClass = isset($tocClass) ? $tocClass : 'toc';
$tocAnchorType = (isset($tocAnchorType) and ($tocAnchorType == 2)) ? 2 : 1;
$tocAnchorLen = (isset($tocAnchorLen) and ($tocAnchorLen > 0)) ? $tocAnchorLen : 0;
/**
 * Транслитерация
 */
$plugin_path = $modx->config['base_path'].'assets/plugins/transalias';
$table_name = isset($table_name) ? $table_name : 'russian';

if (!class_exists('TransAlias')) {
    require_once $plugin_path.'/transalias.class.php';
}
$trans = new TransAlias($modx);

$tocResult = ''; 
$hArray = array(); // массив результатов

$cont = $modx->documentObject['content'];

$contLen = mb_strlen($cont);

for($i=0;$i<$contLen; $i++) {
        
        // Ищем начало заголовка
        $hPosBegin = mb_strpos($cont, "<h", $i);
        
        // позиция начала найденного заголовка любого уровня. При этом мы сразу определяем новую позицию переменной $i - нам нет смысла находить одно место дважды.
        if($hPosBegin !== false) $i = $hPosBegin; else break;
        // ищем конечную позицию
        $hPosEnd = 5 + mb_strpos($cont, "</h", $i); // позиция конца найденого заголовка.
        if($hPosEnd) $i = $hPosEnd; else break;

        // Выделяем заголовок
        $h = mb_substr($cont,$hPosBegin,$hPosEnd-$hPosBegin);
        
        $hLevel = mb_substr($h,2,1);
        
        if($hLevel >= $lStart and $hLevel <= $lEnd) {
                $hArray[$i]['header_in'] = $h;
                $hArray[$i]['level'] = $hLevel;

                // смотрим есть ли у нас здесь уже якорь.
                preg_match("/<a [\s\S]*?name=\"([\w]+)\"/", $h, $getAnchor);
                // записываем бережно заголовок в массив.
                
                if(count($getAnchor) > 1 ){
                        // Если мы нашли уже готовый якорь, то будем пользовать его.
                        $hArray[$i]["anchor"] = $getAnchor[1];
                } else {
                        // нет якоря, значит ставим пока пустоту.
                        $hArray[$i]["anchor"] = "";
                        
                        // определяем позицию якоря
                        $anchorPos = 1 + mb_strpos($hArray[$i]["header_in"], ">", 0);
                        
                        // формируем название якоря
                        if($tocAnchorType == 2) {
                                // используем нумерацию
                                $hArray[$i]["anchor"] = $i;
                        } elseif ($tocAnchorType == 1) {
                                
                                if ($trans->loadTable($table_name)) {
                                        // создаем название якоря путем транслитерации заголовка
                                        $anchorName = $trans->stripAlias($h);
                                        // Если задано ограничение длины, то обрезаем.
                                        if($tocAnchorLen > 0) {
                                                $anchorName = substr($anchorName,0,$tocAnchorLen);
                                        }
                                        // добавляем инфомрацию в результирующий массив
                                        $hArray[$i]["anchor"] = $anchorName;
                                } else {
                                        // используем нумерацию
                                        $hArray[$i]["anchor"] = $i;
                                }
                                
                        }
                        
                        // Модифицируем заголовок
                        $hArray[$i]["header_out"] = mb_substr($hArray[$i]["header_in"], 0, $anchorPos) . "<a name=\"" . $hArray[$i]["anchor"] ."\"></a>" . mb_substr($hArray[$i]["header_in"], $anchorPos);
                        
                        // Заменяем заголовок на модифицированный
                        $cont = str_replace($hArray[$i]["header_in"], $hArray[$i]["header_out"], $cont);
                        
                }
                
        } else {
                $i = $hPosBegin + 5;
        }
        
}

// Создаем само оглавление
if(count($hArray) > 0) {
        
        // ставим уровень текущего заголовка равным 0
        $curLev = 0;
        
        // разбираем массив с заголовками
        foreach ($hArray as $key => $value) {
                
                if($curLev == 0) {
                        // если текущий уровень заголовка равен 0, то надо добавить основной контейнер
                        $tocResult .= '<ul class="' . $tocClass . '_' . $value['level'] . '">';
                } elseif($curLev != $value['level']) {
                        // если текущий уровень заголовка не равен уровню нового пункта, то надо обработать изменение уровня.
                        if($curLev < $value['level']) {
                                // Текущий уровень выше, значит это вложенные пункты и нужен новый контейнер
                                $tocResult .= '<ul class="' . $tocClass . '_' . $value['level'] . '">';
                        } else {
                                // Текущий уровень ниже, значит вложенные пункты закончились
                                $tocResult .= str_repeat('</ul></li>',$curLev - $value['level']);
                        }
                        
                } else {
                        // следующий пункт того же уровня. Значит надо закрыть предыдущий
                        $tocResult .= '</li>';
                }
                
                $id = $modx->documentIdentifier;
                $url = $modx->makeUrl($id,'','','full');
                
                // создаем пункт оглавления
                $tocResult .= '<li><a href="' . $url . '#' . $value['anchor'] . '">' . strip_tags($value['header_in']) . '</a>';
                $curLev = $value['level'];
        }
        
        // закрываем все списки, учитывая текущий уровень вложенности
        $tocResult .= str_repeat('</ul></li>',$curLev - $lStart) . '</ul>';
        
        // Если есть заголовок у оглавления, то оборачиваем его в span с классом, чтобы можно было оформить
        if($tocTitle != '') {
                $tocTitle = '<span class="title">' . $tocTitle . '</span>';
        }
        
        // оборачиваем в контейнер из div с указанным классом
        $tocResult = '<div class="' . $tocClass . '">' . $tocTitle . $tocResult . '</ul></div>';
        
        // изменяем прежнее содержимое
        $modx->documentObject['content'] = $cont;
        
        // записываем оглавление в плейсхолдер [+toc+]
        $modx->setPlaceholder('toc',$tocResult);
        
}

return;

?>