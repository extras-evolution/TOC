//<?php
/**
 * TOC
 *
 * Plugin for automatically creating a table of contents on a page using anchors.
 *
 * @category    plugin
 * @version     0.9.5
 * @license     http://www.gnu.org/copyleft/gpl.html GNU Public License (GPL)
 * @internal    @properties &lStart=Start level;list;1,2,3,4,5,6;2 &lEnd=End level;list;1,2,3,4,5,6;3 &table_name=Transliteration;list;common,russian;common &tocTitle=Title;string;Contents &tocClass=CSS class;string;toc &tocAnchorType=Anchor type;list;1,2;1 &tocAnchorLen=Maximum anchor length;number;0 &exclude_docs=Exclude Documents by id (comma separated);string; &exclude_templates=Exclude Templates by id (comma separated);string;
 * @internal    @events OnLoadWebDocument
 * @internal    @modx_category Content
 * @internal    @legacy_names TOC
 * @internal    @installset base, sample
 */

/**
 * Available parameters:
 *
 * Start level - the starting level of the heading (H1 - H6)
 * End level - the ending level of the heading (H1 - H6)
 * Transliteration - will be used for the first type of anchors. TransAlias plugin tables are used.
 * Title - title for the table of contents. If the field is empty, the title is ignored.
 * CSS class - the style class that will be used in the table of contents (container and nested levels)
 * Anchor type - different variants of generating the anchor name. 1 - transliteration, 2 - numeration
 * Maximum anchor length - used in transliteration and limits the length of the anchor name
 * Exclude Documents by id - A comma separated list of documents id to exclude from the plugin and TOC generation
 * Exclude Templates by id - A comma separated list of templates id to exclude from the plugin and TOC generation
 *
 * Usage:
 *
 * After generation, the table of contents is placed in the global placeholder [+toc+]. Therefore, to display it, you just need to place this placeholder in the appropriate place.
 *
 * Nuances:
 *
 * - large gaps in nesting levels (e.g., H1 - H3) insert extra closing tags
 * - the table of contents is cached, but it does not take into account dynamically added headings
 * - the table of contents is created in all templates, even where it is not used (*)
 * - (*) from version 0.9.4 you can exclude templates and documents
 */

if(!defined('MODX_BASE_PATH')){die('What are you doing? Get out of here!');}

global $modx;

$exclude_docs = explode(',',$exclude_docs);
$exclude_templates = explode(',',$exclude_templates);
// exclude by doc id or template id
$doc_id = $modx -> documentObject['id'];
$template_id = $modx -> documentObject['template'];
	if (!in_array($doc_id,$exclude_docs) && !in_array($template_id,$exclude_templates)) {
$lStart = isset($lStart) ? $lStart : 2;
$lEnd = isset($lEnd) ? $lEnd : 3;
$tocTitle = isset($tocTitle) ? $tocTitle : '';
$tocClass = isset($tocClass) ? $tocClass : 'toc';
$tocAnchorType = (isset($tocAnchorType) and ($tocAnchorType == 2)) ? 2 : 1;
$tocAnchorLen = (isset($tocAnchorLen) and ($tocAnchorLen > 0)) ? $tocAnchorLen : 0;
/**
 * Transliteration
 */
$plugin_path = MODX_BASE_PATH.'assets/plugins/transalias';
$table_name = isset($table_name) ? $table_name : 'russian';

if (!class_exists('TransAlias')) {
    require_once $plugin_path.'/transalias.class.php';
}
$trans = new TransAlias($modx);

$tocResult = ''; 
$hArray = array(); // results array

$cont = $modx->documentObject['content'];

$contLen = mb_strlen($cont);

for($i=0;$i<$contLen; $i++) {
        
        // Search for the beginning of the heading
        $hPosBegin = mb_strpos($cont, "<h", $i);
        
        // position of the beginning of the found heading of any level. At the same time, we immediately determine a new position for the variable $i - we don't need to find the same place twice.
        if($hPosBegin !== false) $i = $hPosBegin; else break;
        // search for the end position
        $hPosEnd = 5 + mb_strpos($cont, "</h", $i); // position of the end of the found heading.
        if($hPosEnd) $i = $hPosEnd; else break;

        // Extract the heading
        $h = mb_substr($cont,$hPosBegin,$hPosEnd-$hPosBegin);
        
        $hLevel = mb_substr($h,2,1);
        
        if($hLevel >= $lStart and $hLevel <= $lEnd) {
                $hArray[$i]['header_in'] = $h;
                $hArray[$i]['level'] = $hLevel;

                // check if we already have an anchor here.
                preg_match("/<a [\s\S]*?name=\"([\w]+)\"/", $h, $getAnchor);
                // carefully record the heading in the array.
                
                if(count($getAnchor) > 1 ){
                        // If we found an existing anchor, we will use it.
                        $hArray[$i]["anchor"] = $getAnchor[1];
                } else {
                        // no anchor, so we'll put an empty string for now.
                        $hArray[$i]["anchor"] = "";
                        
                        // determine the position of the anchor
                        $anchorPos = 1 + mb_strpos($hArray[$i]["header_in"], ">", 0);
                        
                        // form the anchor name
                        if($tocAnchorType == 2) {
                                // use numeration
                                $hArray[$i]["anchor"] = $i;
                        } elseif ($tocAnchorType == 1) {
                                
                                if ($trans->loadTable($table_name,'Yes')) {
                                        // create the anchor name by transliterating the heading
                                        $anchorName = $trans->stripAlias($h,'lowercase alphanumeric','-');
                                        // If a length limit is set, we truncate it.
                                        if($tocAnchorLen > 0) {
                                                $anchorName = substr($anchorName,0,$tocAnchorLen);
                                        }
                                        // add information to the resulting array
                                        $hArray[$i]["anchor"] = $anchorName;
                                } else {
                                        // use numeration
                                        $hArray[$i]["anchor"] = $i;
                                }
                                
                        }
                        
                        // Modify the heading
                        $hArray[$i]["header_out"] = mb_substr($hArray[$i]["header_in"], 0, $anchorPos) . "<a name=\"" . $hArray[$i]["anchor"] ."\"></a>" . mb_substr($hArray[$i]["header_in"], $anchorPos);
                        
                        // Replace the heading with the modified one
                        $cont = str_replace($hArray[$i]["header_in"], $hArray[$i]["header_out"], $cont);
                        
                }
                
        } else {
                $i = $hPosBegin + 5;
        }
	
}

// Create the table of contents
if(count($hArray) > 0) {
    $curLev = 0;
    $openLiCount = 0; // keeps trace of open <li> 
    
    foreach ($hArray as $key => $value) {
        if($curLev == 0) {
            $tocResult .= '<ul class="' . $tocClass . '_' . $value['level'] . '">';
        } elseif($curLev != $value['level']) {
            if($curLev < $value['level']) {
                $tocResult .= '<ul class="lev2 ' . $tocClass . '_' . $value['level'] . '">';
            } else {
                // Close all the <li> and <ul> needed when they go down
                $tocResult .= str_repeat('</li></ul>', $curLev - $value['level']);
                $openLiCount -= ($curLev - $value['level']); // Update the <li> count
            }
        } else {
            $tocResult .= '</li>';
            $openLiCount--;
        }
        
        $id = $modx->documentIdentifier;
        $url = $modx->makeUrl($id,'','','full');
        
        // Add the new <li>
        $curLev = $value['level'];
        if($curLev == $lStart) {
            $tocResult .= '<li class="TocTop"><a href="' . $url . '#' . $value['anchor'] . '">' . strip_tags($value['header_in']) . '</a>';
        } else {
            $tocResult .= '<li><a href="' . $url . '#' . $value['anchor'] . '">' . strip_tags($value['header_in']) . '</a>';
        }
        $openLiCount++; // increases the <li> count
    }
    
    // correctly close all the remaining tags
    if($openLiCount > 0) {
        $tocResult .= str_repeat('</li>', $openLiCount);
    }
    $tocResult .= str_repeat('</ul>', $curLev > 0 ? $curLev - $lStart + 1 : 1);

    // Add the title if present
    if($tocTitle != '') {
        $tocTitle = '<span class="title">' . $tocTitle . '</span>';
    }
    
    $tocResult = '<div class="' . $tocClass . '">' . $tocTitle . $tocResult . '</div>';
    
    $modx->documentObject['content'] = $cont;
    $modx->setPlaceholder('toc', $tocResult);
}
}
return;