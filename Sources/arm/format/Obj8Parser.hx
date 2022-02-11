package arm.format;

import iron.math.Vec4;
import iron.math.Vec3;
import iron.math.Vec2;
import iron.math.Quat;
import iron.math.Mat4;

class Obj8_vtx {
	public var vtx: iron.math.Vec3 = null;
	public var nor: iron.math.Vec3 = null;
	public var tex: iron.math.Vec2 = null;
	
	public function new(vtx:Vec3, nor:Vec3, tex:Vec2) {
		this.vtx = vtx;
		this.nor = nor;
		this.tex = tex;
	}
	
	public function clone(){
		return new Obj8_vtx(this.vtx.clone(), this.nor.clone(), this.tex.clone());
	}
}

class Obj8_axis_angle {
	public var vector : iron.math.Vec4 = null;
	public var angle : Float;
	public function new(x:Float, y:Float, z:Float , angle:Float) {
			this.vector = new Vec4(x,y,z);
			this.angle = angle * Math.PI / 180.0;//convert to radians
	}	
	
}

class Obj8_Anim {
	public var translate_static : iron.math.Vec4 = null;
	public var rotate_static :  iron.math.Quat = null;
	public var translate_key : iron.math.Vec4 = null;
	public var rotate_key :  iron.math.Quat = null;
	public var helper_vec : iron.math.Vec4 = null; 
	
	public var parent :  Obj8_Anim = null;
	
	public function new(parent: Obj8_Anim) {
			this.parent = parent;
			this.translate_static = new Vec4();
			this.rotate_static = new Quat();
			this.translate_key = new Vec4();
			this.rotate_key = new Quat();
	}
}

class Obj8Parser {

	public var posa: kha.arrays.Int16Array = null;
	public var nora: kha.arrays.Int16Array = null;
	public var texa: kha.arrays.Int16Array = null;
	public var inda: kha.arrays.Uint32Array = null;
	public var scalePos = 1.0;
	public var scaleTex = 1.0;
	public var name = "";
	public var curObj = 0;
	
	var vtxTable: Array<Obj8_vtx> = [];
	var idxTable: Array<Int> = [];
	var objTable: Array<Array<Obj8_vtx>> = [];


	public function new(blob: kha.Blob) {

		var input = new haxe.io.BytesInput(blob.bytes);

		while (input.position < input.length){
			
			var line = trimstr(input.readLine());
			
			var str = line.split(" ");

			if (str[0] == "VT"){
			var vtx  = new Obj8_vtx(new Vec3(Std.parseFloat(str[1]), -Std.parseFloat(str[3]), Std.parseFloat(str[2])), new Vec3(Std.parseFloat(str[4]), -Std.parseFloat(str[6]), Std.parseFloat(str[5])), new Vec2(Std.parseFloat(str[7]), 1 - Std.parseFloat(str[8])));
				vtxTable.push(vtx);
			}
			else if (str[0] == "IDX10"){
				for(i in 1...11){
					idxTable.push(Std.parseInt(str[i]));
				}
			}
			else if (str[0] == "IDX"){
				idxTable.push(Std.parseInt(str[1]));
			}
			else if (str[0] == "ANIM_begin"){
					var anim = new Obj8_Anim(null);
					parseAnim(input, anim);
			}
			else if (str[0] == "TRIS"){
				var startIdx = Std.parseInt(str[1]);
				var offsetIdx = Std.parseInt(str[2]);
				var endIdx = startIdx + offsetIdx;
				var tmpObj = new Array<Obj8_vtx>(); 
					
				//Unoptimize	
				for (i in startIdx...endIdx) {
					var vtx = vtxTable[idxTable[i]].clone();
					tmpObj.push(vtx);
				}

				objTable.push(tmpObj);
			}
		}

		next();
	}
	
	public function next(): Bool {
		
		if(curObj >= objTable.length) return false;
		
		posa = new kha.arrays.Int16Array(objTable[curObj].length * 4);
		inda = new kha.arrays.Uint32Array(objTable[curObj].length);
		nora = new kha.arrays.Int16Array(objTable[curObj].length * 2);
		texa = new kha.arrays.Int16Array(objTable[curObj].length * 2);

		// Pack positions to (-1, 1) range
		scalePos = 0.0;		
		for(v in objTable[curObj]){
				var f = Math.abs(v.vtx.x);
				if (scalePos < f) scalePos = f;
				f = Math.abs(v.vtx.y);
				if (scalePos < f) scalePos = f;
				f = Math.abs(v.vtx.z);
				if (scalePos < f) scalePos = f;
		}
		var inv = 32767 * (1 / scalePos);
		
		var idx = 0;
		var ind = objTable[curObj].length - 1;
		while(ind >= 0 ){
			posa[idx * 4	] = Std.int( objTable[curObj][ind].vtx.x*inv);
			posa[idx * 4 + 1] = Std.int( objTable[curObj][ind].vtx.y*inv);
			posa[idx * 4 + 2] = Std.int( objTable[curObj][ind].vtx.z*inv);
			
			nora[idx * 2    ] = Std.int( objTable[curObj][ind].nor.x * 32767);
			nora[idx * 2 + 1] = Std.int( objTable[curObj][ind].nor.y * 32767);
			posa[idx * 4 + 3] = Std.int( objTable[curObj][ind].nor.z * 32767);

			texa[idx * 2    ] = Std.int( objTable[curObj][ind].tex.x  * 32767);
			texa[idx * 2 + 1] = Std.int( (objTable[curObj][ind].tex.y) * 32767);
				
			
			inda[idx] = idx;
			idx++;
			ind--;
		}
		curObj++;
		return true;
	}
	
	function parseAnim(input: haxe.io.BytesInput, anim_obj : Obj8_Anim){

		while (input.position < input.length){
			
			var line = trimstr(input.readLine());
			
			var str = line.split(" ");


			if (str[0] == "ANIM_begin"){
					var anim = new Obj8_Anim(anim_obj);
					parseAnim(input, anim);
			}		
			if (str[0] == "ANIM_rotate_begin"){
					anim_obj.helper_vec = new Vec4(Std.parseFloat(str[1]), -Std.parseFloat(str[3]), Std.parseFloat(str[2]));
			}	
			if (str[0] == "ANIM_trans_begin"){
					anim_obj.helper_vec = new Vec4();
			}
			else if (str[0] == "ANIM_rotate_key" && anim_obj.helper_vec == null){
				//Use anim_obj.helper_vec == null to test if we already paresed one key
				//Assume first angle is rest pose
				var angle = Std.parseFloat(str[2]);
				
				var axis_angle = new Obj8_axis_angle(anim_obj.helper_vec.x, anim_obj.helper_vec.y, anim_obj.helper_vec.z, angle);
				var q = new Quat();
				q.fromAxisAngle(axis_angle.vector, axis_angle.angle);
				anim_obj.rotate_key.mult(q);
				
				break;
				
			}
			else if (str[0] == "ANIM_trans_key" && anim_obj.helper_vec == null){
				//Use anim_obj.helper_vec == null to test if we already paresed one key
				var trans = new Vec4(Std.parseFloat(str[2]), -Std.parseFloat(str[4]), Std.parseFloat(str[3]));
				anim_obj.translate_key.add(trans);
				break;
			}
			else if (str[0] == "ANIM_trans"){
				//Assume first position is rest pose
				var trans = new Vec4(Std.parseFloat(str[1]), -Std.parseFloat(str[3]), Std.parseFloat(str[2]));

					anim_obj.translate_static.add(trans);
			}
			else if (str[0] == "ANIM_rotate"){
				//Assume first angle is rest pose
				var angle = Std.parseFloat(str[4]);
				var axis_angle = new Obj8_axis_angle(Std.parseFloat(str[1]), -Std.parseFloat(str[3]), Std.parseFloat(str[2]), angle);

				var q = new Quat();
				q.fromAxisAngle(axis_angle.vector, axis_angle.angle);
				anim_obj.rotate_static.mult(q);				
			}
			else if (str[0] == "TRIS"){
				var startIdx = Std.parseInt(str[1]);
				var offsetIdx = Std.parseInt(str[2]);
				var endIdx = startIdx + offsetIdx;
				var tmpObj = new Array<Obj8_vtx>(); 
					
				//Unoptimize	
				for (i in startIdx...endIdx) {
					var vtx = vtxTable[idxTable[i]].clone();
					tmpObj.push(vtx);
				}
				

				var obj = anim_obj;
				while(true){
					var mat = Mat4.identity();

					mat.compose(obj.translate_static, obj.rotate_static, new Vec4(1,1,1,1));
					mat.applyQuat(obj.rotate_key);
					for(v in tmpObj){
							v.vtx.applymat(mat);
					}
					//not shure I need this
					mat.toRotation();
					for(v in tmpObj){			
							v.nor.applymat(mat);
							v.nor.normalize();
					}

					if(obj.parent == null) break;
					obj = obj.parent;
				}

				objTable.push(tmpObj);							
			}
			else if (str[0] == "ANIM_end"){
				break;
			}
		}	
	}
	
	function trimstr(str: String) : String{
	//different exporters put white spaces and tabs all over the place.
      if (str.length == 0)
          return str;

      var sb = new String("");
      var needWhiteSpace = false;
      for (pos in 0...str.length) {
         if (str.isSpace(pos)) {
            if (sb.length > 0)
               needWhiteSpace = true;
            continue;
         } else if (needWhiteSpace && pos < str.length) {
            sb = sb + " ";
            needWhiteSpace = false;
         }
         sb += str.charAt(pos);
      }
      return sb;
		
	}



}
