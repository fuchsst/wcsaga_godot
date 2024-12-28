## BSPDataStructs.cpp

```cpp


#include 
#include <memory.h>
#include <cmath>


int BSP_BlockHeader::Read(char *buffer) {
	memcpy(&id, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&size, buffer, sizeof(int));
	buffer += sizeof(int);

	return MySize();
}

int BSP_BlockHeader::Write(char *buffer)
{
	memcpy(buffer, &id, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &size, sizeof(int));
	buffer += sizeof(int);

	return 8;
}



int BSP_DefPoints::Read(char *buffer, BSP_BlockHeader hdr)
{
	char *temp = buffer;

	head = hdr;
	memcpy(&n_verts, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&n_norms, buffer,sizeof(int));
	buffer += sizeof(int);

	memcpy(&offset, buffer,sizeof(int));
	buffer += sizeof(int);

	norm_counts.resize(n_verts);
	memcpy(&norm_counts.front(), buffer, n_verts);
	buffer += n_verts;

		vertex_data.resize(n_verts);

		buffer = temp;
	buffer += (offset-8);
	
	for (int i = 0; i < n_verts; i++)
	{
		memcpy(&vertex_data[i].vertex, buffer, sizeof(vector3d));
		buffer += sizeof(vector3d);

		if (int(norm_counts[i]) > 0)
		{
			vertex_data[i].norms.resize(norm_counts[i]);
			memcpy(&vertex_data[i].norms.front(), buffer, sizeof(vector3d) * int(norm_counts[i]));
			size_t normal_offset = normals.size();
			normals.resize(normals.size() + norm_counts[i]);
			memcpy(&normals.front() + normal_offset, buffer, sizeof(vector3d)* int(norm_counts[i]));
			buffer += (sizeof(vector3d) * norm_counts[i]);
		}
		else
			vertex_data[i].norms.clear();
	}
	
	return MySize();
}

int BSP_DefPoints::Write(char *buffer)
{
	int Collector = 0;
	char *tbuff = buffer;

	head.size = MySize();
	tbuff += head.Write(tbuff); 
	memcpy(tbuff, &n_verts, sizeof(int));
	tbuff += sizeof(int);

	memcpy(tbuff, &n_norms, sizeof(int));
	tbuff += sizeof(int);

	memcpy(tbuff, &offset, sizeof(int));
	tbuff += sizeof(int);

	memcpy(tbuff, &norm_counts.front(), n_verts);
	tbuff += n_verts;

		for (int i = 0; i < n_verts; i++)
	{
		memcpy(tbuff, &vertex_data[i].vertex, sizeof(vector3d));
		tbuff += sizeof(vector3d);

		if (norm_counts[i])
		{
			memcpy(tbuff, &vertex_data[i].norms.front(), sizeof(vector3d) * ((int) (unsigned char)norm_counts[i]));
			tbuff += (sizeof(vector3d) * norm_counts[i]);
			Collector += int(norm_counts[i]);
		}
	}
	
	return (unsigned int)(tbuff-buffer);
}


int BSP_DefPoints::MySize()
{
	
	int Collector = 0;

	for (int i = 0; i < n_verts; i++)
	{
		Collector += (int) ((unsigned char)norm_counts[i]);
	}

	return (20 + n_verts + (sizeof(vector3d) * (Collector + n_verts)));
}


int Flat_vertex::Read(char *buffer)
{
	memcpy(&vertnum, buffer, sizeof(short));
	buffer += sizeof(short);

	memcpy(&normnum, buffer, sizeof(short));
	buffer += sizeof(short);

	return MySize();
}

int Flat_vertex::Write(char *buffer)
{
	memcpy(buffer, &vertnum, sizeof(short));
	buffer += sizeof(short);

	memcpy(buffer, &normnum, sizeof(short));
	buffer += sizeof(short);

	return 4;
}


int BSP_FlatPoly::Read(char *buffer, BSP_BlockHeader hdr)
{
	head = hdr;

	memcpy(&normal, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&center, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&radius, buffer, sizeof(float));
	buffer += sizeof(float);

	memcpy(&nverts, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&red, buffer, sizeof(byte));
	buffer += sizeof(byte);

	memcpy(&green, buffer, sizeof(byte));
	buffer += sizeof(byte);

	memcpy(&blue, buffer, sizeof(byte));
	buffer += sizeof(byte);

	memcpy(&pad, buffer, sizeof(byte));
	buffer += sizeof(byte);

	verts.resize(nverts);

	for (int i = 0; i < nverts; i++)
	{
		verts[i].Read(buffer);
		buffer += 4; 	}

	return MySize();

}


vector3d BSP_FlatPoly::MyCenter(std::vector<vector3d> Verts)
{

	float TotalArea=0, triarea;
	vector3d Centroid = MakeVector(0,0,0), midpoint;


	for (size_t i = 0; i < Verts.size(); i++)
	{
		midpoint = Verts[i] + Verts[i+1] + Verts[i+2];
		midpoint = midpoint/3;

		
		triarea = Magnitude(CrossProduct(Verts[i+1]-Verts[i],
										 Verts[i+2]-Verts[i])); 		midpoint = triarea*midpoint;
		TotalArea += triarea;
		Centroid += midpoint;

	}

	Centroid = float(1.0 / TotalArea) * Centroid;
	return Centroid;

}

float BSP_FlatPoly::MyRadius(vector3d c, std::vector<vector3d> Verts)
{
	float RetVal=0;


	vector3d max;
	max.x = Abs(Verts[0].x);
	max.y = Abs(Verts[0].y);
	max.z = Abs(Verts[0].z);

	for (int i = 0; i < nverts; i++)
	{
		if (Abs(Verts[i].x) > max.x)
			max.x = Abs(Verts[i].x);

		if (Abs(Verts[i].y) > max.y)
			max.y = Abs(Verts[i].y);

		if (Abs(Verts[i].z) > max.z)
			max.z = Abs(Verts[i].z);
	}

	RetVal =	((max.x-Abs(c.x)) * (max.x-Abs(c.x))) +
				((max.y-Abs(c.y)) * (max.y-Abs(c.y))) +
				((max.z-Abs(c.z)) * (max.z-Abs(c.z)));
	RetVal = float(sqrt(RetVal));

	return RetVal;
}



int BSP_FlatPoly::Write(char *buffer)
{
	buffer += head.Write(buffer);

	memcpy(buffer, &normal, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &center, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &radius, sizeof(float));
	buffer += sizeof(float);

	memcpy(buffer, &nverts, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &red, sizeof(byte));
	buffer += sizeof(byte);

	memcpy(buffer, &green, sizeof(byte));
	buffer += sizeof(byte);

	memcpy(buffer, &blue, sizeof(byte));
	buffer += sizeof(byte);

	memcpy(buffer, &pad, sizeof(byte));
	buffer += sizeof(byte);

	for (int i = 0; i < nverts; i++)
	{
		buffer += verts[i].Write(buffer);
	}

	return (head.MySize() + (4  * nverts)
			+ (sizeof(byte) * 4) + sizeof(int) + sizeof(float) + (sizeof(vector3d) * 2));


}



int Tmap_vertex::Read(char *buffer)
{
	memcpy(&vertnum, buffer, sizeof(short));
	buffer += sizeof(short);

	memcpy(&normnum, buffer, sizeof(short));
	buffer += sizeof(short);

	memcpy(&u, buffer, sizeof(float));
	buffer += sizeof(float);

	memcpy(&v, buffer, sizeof(float));
	buffer += sizeof(float);

	return MySize();
}


int Tmap_vertex::Write(char *buffer)
{
	memcpy(buffer, &vertnum, sizeof(short));
	buffer += sizeof(short);

	memcpy(buffer, &normnum, sizeof(short));
	buffer += sizeof(short);

	memcpy(buffer, &u, sizeof(float));
	buffer += sizeof(float);

	memcpy(buffer, &v, sizeof(float));
	buffer += sizeof(float);

	return ((sizeof(short) * 2) + (sizeof(float) * 2));
}


int BSP_TmapPoly::Read(char *buffer, BSP_BlockHeader hdr)
{
	head = hdr;

	memcpy(&normal, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&center, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&radius, buffer, sizeof(float));
	buffer += sizeof(float);

	memcpy(&nverts, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&tmap_num, buffer, sizeof(int));
	buffer += sizeof(int);

	verts.resize(nverts);

	for (int i =0; i < nverts; i++)
	{
		verts[i].Read(buffer);
		buffer += 12; 	}

	return MySize();

}

vector3d BSP_TmapPoly::MyCenter(std::vector<vector3d> Verts)
{

	float TotalArea=0, triarea;
	vector3d Centroid = MakeVector(0,0,0), midpoint;


	for (int i = 0; i < nverts-2; i++)
	{
		midpoint = Verts[i] + Verts[i+1] + Verts[i+2];
		midpoint = midpoint/3;

		
		triarea = Magnitude(CrossProduct(Verts[i+1]-Verts[i],
										 Verts[i+2]-Verts[i])); 		midpoint = triarea*midpoint;
		TotalArea += triarea;
		Centroid += midpoint;

	}

	Centroid = float(1.0 / TotalArea) * Centroid;
	return Centroid;
}

float BSP_TmapPoly::MyRadius(vector3d c, std::vector<vector3d> Verts)
{
	float RetVal=0;


	vector3d max;
	max.x = Abs(Verts[0].x);
	max.y = Abs(Verts[0].y);
	max.z = Abs(Verts[0].z);

	for (int i = 0; i < nverts; i++)
	{
		if (Abs(Verts[i].x) > max.x)
			max.x = Abs(Verts[i].x);

		if (Abs(Verts[i].y) > max.y)
			max.y = Abs(Verts[i].y);

		if (Abs(Verts[i].z) > max.z)
			max.z = Abs(Verts[i].z);
	}

	RetVal =	((max.x-Abs(c.x)) * (max.x-Abs(c.x))) +
				((max.y-Abs(c.y)) * (max.y-Abs(c.y))) +
				((max.z-Abs(c.z)) * (max.z-Abs(c.z)));
	RetVal = float(sqrt(RetVal));

	return RetVal;
}


int BSP_TmapPoly::Write(char *buffer)
{
	buffer += head.Write(buffer);

	memcpy(buffer, &normal, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &center, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &radius, sizeof(float));
	buffer += sizeof(float);

	memcpy(buffer, &nverts, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &tmap_num, sizeof(int));
	buffer += sizeof(int);

	for (int i =0; i < nverts; i++)
	{

		buffer += verts[i].Write(buffer); 	}

	return ((12 * nverts) + (sizeof(int) * 2) + sizeof(float) + (sizeof(vector3d) * 2));
}


int BSP_SortNorm::Read(char *buffer, BSP_BlockHeader hdr)
{
	head = hdr;

	memcpy(&plane_normal, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&plane_point, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&reserved, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&front_offset, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&back_offset, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&prelist_offset, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&postlist_offset, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&online_offset, buffer, sizeof(int));
	buffer += sizeof(int);

	memcpy(&min_bounding_box_point, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&max_bounding_box_point, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	return MySize();
}

int BSP_SortNorm::Write(char *buffer)
{
	buffer += head.Write(buffer); 
	memcpy(buffer, &plane_normal, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &plane_point,sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &reserved, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &front_offset, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &back_offset, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &prelist_offset, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &postlist_offset,sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &online_offset, sizeof(int));
	buffer += sizeof(int);

	memcpy(buffer, &min_bounding_box_point, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &max_bounding_box_point, sizeof(vector3d));
	buffer += sizeof(vector3d);

	return 72;
}



int BSP_BoundBox::Read(char *buffer, BSP_BlockHeader hdr)
{
	head = hdr;
	memcpy(&min_point, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(&max_point, buffer, sizeof(vector3d));
	buffer += sizeof(vector3d);

	return MySize();
}

int BSP_BoundBox::Write(char *buffer)
{
	buffer += head.Write(buffer);

	memcpy(buffer, &min_point, sizeof(vector3d));
	buffer += sizeof(vector3d);

	memcpy(buffer, &max_point, sizeof(vector3d));
	buffer += sizeof(vector3d);

	return 30;
}



bool operator==(BSP_TmapPoly &a, BSP_TmapPoly &b)
{
	bool Ret = ((a.center == b.center) && (a.radius == b.radius) && (a.normal == b.normal) && (a.nverts == b.nverts));

	if (Ret)
	{
		for (int i = 0; i < a.nverts; i++)
		{
			if (!(a.verts[i].normnum == b.verts[i].normnum &&
				a.verts[i].vertnum == b.verts[i].vertnum &&
				a.verts[i].u == b.verts[i].u &&
				a.verts[i].v == b.verts[i].v))
				return false;

		}
	}
	else return false;
	return true;
}



bool operator==(BSP_FlatPoly &a, BSP_FlatPoly &b)
{
	bool Ret = ((a.center == b.center) && (a.radius == b.radius) && (a.normal == b.normal) && (a.nverts == b.nverts));

	if (Ret)
	{
		for (int i = 0; i < a.nverts; i++)
		{
			if (!(a.verts[i].normnum == b.verts[i].normnum &&
				a.verts[i].vertnum == b.verts[i].vertnum))
				return false;

		}
	}
	else
		return false;
	return true;
}

```

## BSPDataStructs.h

```cpp



#include 
#include <memory.h>
#include <string>

#if !defined(_BSP_DATA_STRUCTS_H_)
#define _BSP_DATA_STRUCTS_H_

typedef unsigned char byte;


struct BSP_BlockHeader
{
	int id;
		int size; 
		int Read(char *buffer);
	int Write(char *buffer);
	int MySize()
		{ return 8; }
};


struct vertdata
{
	vector3d vertex;
	std::vector<vector3d> norms;
};

struct BSP_DefPoints {
	BSP_BlockHeader head;				int n_verts;						int n_norms;						int offset;							std::vector<unsigned char> norm_counts;			    	std::vector<vertdata> vertex_data;				
	std::vector<vector3d> normals;

		BSP_DefPoints() {
		head.id = 0;
		head.size = 0;
		n_verts = 0;
		n_norms = 0;
		offset = 0;
	}
	int Read(char *buffer, BSP_BlockHeader hdr);
	int Write(char *buffer);
	int MySize();
};


struct Flat_vertex
{
   unsigned short vertnum;    unsigned short normnum;

		int Read(char *buffer);
	int Write(char *buffer);
	int MySize()
		{ return 4; }
};

struct BSP_FlatPoly {                          
	BSP_BlockHeader head;		vector3d normal;				vector3d center;				float radius;				int nverts;					byte red;					byte green;					byte blue;					byte pad;					std::vector<Flat_vertex> verts;

  		int Read(char *buffer, BSP_BlockHeader hdr);
	int Write(char *buffer);
	int MySize()
		{	return 44 + (4 * nverts);  }
	float MyRadius(vector3d center, std::vector<vector3d> Verts);
	vector3d MyCenter(std::vector<vector3d> Verts);
};

struct Tmap_vertex
{
	unsigned short vertnum; 	unsigned short normnum;
	float u;
	float v;

   		int Read(char *buffer);
	int Write(char *buffer);
	int MySize()
		{ return 12; }

};

struct BSP_TmapPoly { 
	BSP_BlockHeader head;		vector3d normal;			vector3d center;			float radius;				int nverts;					int tmap_num;				std::vector<Tmap_vertex> verts;		
		int Read(char *buffer, BSP_BlockHeader hdr);
	int Write(char *buffer);
	int MySize()
		{ return ((12 * nverts) + 44); }
	float MyRadius(vector3d center, std::vector<vector3d> Verts);
	vector3d MyCenter(std::vector<vector3d> Verts);

};



struct BSP_SortNorm {
	BSP_BlockHeader head;				vector3d plane_normal;				vector3d plane_point;					int reserved;						int front_offset;					int back_offset;					int prelist_offset;					int postlist_offset;				int online_offset;					vector3d min_bounding_box_point;		vector3d max_bounding_box_point;	
		BSP_SortNorm() : reserved(0), front_offset(0), back_offset(0), prelist_offset(0), postlist_offset(0), online_offset(0) {}
	int Read(char *buffer, BSP_BlockHeader hdr);
	int Write(char *buffer);
	int MySize()
		{ return 80; }
};

struct BSP_BoundBox {
	BSP_BlockHeader head; 	vector3d min_point;	  	vector3d max_point;	  
		int Read(char *buffer, BSP_BlockHeader hdr);
	int Write(char *buffer);
	int MySize()
		{ return 32; }
};

#endif 
```

## BSPHandler.cpp

```cpp



#if !defined(_WIN32)
#include 
#include 
#endif
#include 
#include <cstdio>
#include <memory.h>
#include <iostream>

using namespace std;

std::string BSP::DataIn(char *buffer, int size)
{
	std::string stats;
	char *localptr = buffer;
	char cstemp[64];
	bool go = true;
	BSP_BoundBox	bnd;
	BSP_DefPoints	pnt;
	BSP_FlatPoly	fpol;
	BSP_SortNorm	snrm;
	BSP_TmapPoly	tpol;

	BSP_BlockHeader head;

	stats = ;
		while (go)
	{


		head.Read(localptr);
		localptr += 8;


		if (localptr - buffer >= size)
		{
			go = false;
			break;
		}
		switch (head.id)
		{
			case 0:
																break;

			case 1:

				memset(cstemp, 0, 64);
				sprintf(cstemp, , head.size, head.size - pnt.Read(localptr, head));
				localptr += (head.size - 8);
												
				
				
				Add_DefPoints(pnt);
				break;

			case 2:
				
				memset(cstemp, 0, 64);
				sprintf(cstemp, , head.size, head.size - fpol.Read(localptr, head));
				localptr += (head.size - 8);
				

				
				Add_FlatPoly(fpol);
				break;

			case 3:
			
				memset(cstemp, 0, 64);
				sprintf(cstemp, , head.size, head.size - tpol.Read(localptr, head));
				localptr += (head.size - 8);								


				

				
				Add_TmapPoly(tpol);
				break;

			case 4:
				stats += ;


				memset(cstemp, 0, 64);
				sprintf(cstemp, , head.size, head.size - snrm.Read(localptr, head));
				localptr += (head.size - 8);								
				

				Add_SortNorm(snrm);
				break;

			case 5:
				
				memset(cstemp, 0, 64);
				sprintf(cstemp, , head.size, head.size - bnd.Read(localptr, head));
				localptr += (head.size - 8);				


				Add_BoundBox(bnd);
				break;

			default:
				stats += ;
				go = false;
				break;

		}
	}

	return stats;
}



std::ostream& BSP::BSPDump(std::ostream &os) {
	int i;
	for (i = 0; i < numpoints; i++)
	{
		os <<  << i <<  << std::endl;
		os <<  << points[i].n_verts << std::endl;
		os <<  << points[i].n_norms << std::endl;
		os <<  << points[i].offset << std::endl;

		for (int j = 0; j < points[i].n_verts; j++)
		{
			os <<  << j <<  << points[i].vertex_data[j].vertex << std::endl;
			for (int k = 0; k < points[i].norm_counts[j]; k++)
				os <<  << k <<  << points[i].vertex_data[j].norms[k] << std::endl;
		}

	}

	os <<  << std::endl;

	for (i = 0; i < numtpolys; i++)
	{
		os <<  << i << std::endl;
		os <<  << tpolys[i].normal << std::endl;
		os <<  << tpolys[i].center << std::endl;
		os <<  << tpolys[i].radius << std::endl;
		os <<  << tpolys[i].tmap_num << std::endl;
		os <<  << tpolys[i].nverts << std::endl;
		for (int j = 0; j < tpolys[i].nverts; j++)
		{
			os <<  << tpolys[i].verts[j].vertnum << std::endl;
			os <<  << tpolys[i].verts[j].normnum << std::endl;
			os <<  << tpolys[i].verts[j].u << std::endl;
			os <<  << tpolys[i].verts[j].v << std::endl;
		}
	}
	return os;
}


void BSP::Add_BoundBox(BSP_BoundBox bound)
{
	bounders.push_back(bound);

}

bool BSP::Del_BoundBox(int index)
{
	if (index < 0 || index >= numbounders)
		return false;
	bounders.erase(bounders.begin() + index);
	return true;
}



void BSP::Add_DefPoints(BSP_DefPoints pnts)
{
	points.push_back(pnts);
}

bool BSP::Del_DefPoints(int index)
{
	if (index < 0 || index >= numpoints)
		return false;
	points.erase(points.begin() + index);
	return true;
}


void BSP::Add_FlatPoly(BSP_FlatPoly fpol)
{
	fpolys.push_back(fpol);
}

bool BSP::Del_FlatPoly(int index)
{
	if (index < 0 || index >= numfpolys)
		return false;
	fpolys.erase(fpolys.begin() + index);
	return true;
}


void BSP::Add_SortNorm(BSP_SortNorm sn)
{
	snorms.push_back(sn);
}

bool BSP::Del_SortNorm(int index)
{
	if (index < 0 || index >= numsnorms)
		return false;
	snorms.erase(snorms.begin() + index);
	return true;
}


void BSP::Add_TmapPoly(BSP_TmapPoly tpol)
{
	tpolys.push_back(tpol);
}


bool BSP::Del_TmapPoly(int index)
{
	if (index < 0 || index >= numtpolys)
		return false;
	tpolys.erase(tpolys.begin() + index);
	return true;
}

std::ostream& operator<<( std::ostream &os, BSP_TmapPoly tpoly)
{
	os <<  << std::endl;
	os <<  << tpoly.center << std::endl;
	os <<  << tpoly.normal << std::endl;
	os <<  << tpoly.radius << std::endl;
	os <<  << tpoly.nverts << std::endl;
	os <<  << tpoly.tmap_num << std::endl;
	return os;
}

std::ostream& operator<<( std::ostream &os, BSP_FlatPoly fpoly)
{

	os <<  << std::endl;
	os <<  << fpoly.center << std::endl;
	os <<  << fpoly.normal << std::endl;
	os <<  << fpoly.radius << std::endl;
	os <<  << fpoly.nverts << std::endl;
	os <<  << int(fpoly.red) << 
	   << int(fpoly.green) <<  << int(fpoly.blue) << std::endl;
	os <<  << int(fpoly.pad) << std::endl;
	return os;
}

```

## BSPHandler.h

```cpp



#include 
#include <ios>


#if !defined(_BSP_HANDLER_H_)
#define _BSP_HANDLER_H_


class BSP
{
	public:
		std::vector<BSP_BoundBox> bounders;
		std::vector<BSP_DefPoints> points;
		std::vector<BSP_FlatPoly> fpolys;
		std::vector<BSP_SortNorm> snorms;
		std::vector<BSP_TmapPoly> tpolys;

		int numbounders, numpoints, numfpolys, numsnorms, numtpolys;
		void Clear()
		{
			bounders.clear();
			points.clear();
			fpolys.clear();
			snorms.clear();
			tpolys.clear();
		}

		BSP()
			{ Clear(); }
		BSP(char *buffer, int size)
			{ Clear();
			  DataIn(buffer, size); }
		
				std::string DataIn(char *buffer, int size);
		std::ostream& BSPDump(std::ostream &os); 
		int Count_Bounding()
			{ return bounders.size(); }

		int Count_Points()
		{
			return points.size();
		}
		
		int Count_FlatPolys()
		{
			return fpolys.size();
		}

		int Count_SortNorms()
		{
			return snorms.size();
		}

		int Count_TmapPolys()
		{
			return tpolys.size();
		}

				
		void Add_BoundBox(BSP_BoundBox bound);
		bool Del_BoundBox(int index);

		void Add_DefPoints(BSP_DefPoints pnts);
		bool Del_DefPoints(int index);

		void Add_FlatPoly(BSP_FlatPoly fpol);
		bool Del_FlatPoly(int index);

		void Add_SortNorm(BSP_SortNorm sn);
		bool Del_SortNorm(int index);

		void Add_TmapPoly(BSP_TmapPoly tpol);
		bool Del_TmapPoly(int index);

};


std::ostream& operator<<( std::ostream &os, BSP_TmapPoly tpoly);
std::ostream& operator<<( std::ostream &os, BSP_FlatPoly fpoly);
bool operator==(BSP_TmapPoly &a, BSP_TmapPoly &b);
bool operator==(BSP_FlatPoly &a, BSP_FlatPoly &b);

#endif 
```

## glow_points.h

```cpp
#pragma once

#include"model_editor_ctrl.h"
#include"array_ctrl.h"
#include"primitive_ctrl.h"
#include"pcs_file.h"


class glow_point_ctrl :
	public editor<pcs_thrust_glow>
{
protected:
	float_ctrl*rad;
	vector_ctrl*pos;
	normal_ctrl*norm;
public:
	
	glow_point_ctrl(wxWindow*parent,  wxString Title, int orient = wxVERTICAL)
	:editor<pcs_thrust_glow>(parent, orient, Title)
	{
				add_control(rad=new float_ctrl(this,_("Radius")),0,wxEXPAND );
		add_control(pos=new vector_ctrl(this,_("position")),0,wxEXPAND );
		add_control(norm=new normal_ctrl(this,_("Normal")),0,wxEXPAND );
	};

	virtual ~glow_point_ctrl(void){};

	void set_value(const pcs_thrust_glow&t){
		pos->set_value(t.pos);
		norm->set_value(t.norm);
		rad->set_value(t.radius);
	}

		pcs_thrust_glow get_value(){
		pcs_thrust_glow t;
		t.pos = pos->get_value();
		t.norm = norm->get_value();
		t.radius = rad->get_value();
		return t;
	}
	
};

class glow_point_array_ctrl :
	public type_array_ctrl<pcs_thrust_glow, glow_point_ctrl>
{
public:
	glow_point_array_ctrl(wxWindow*parent, wxString Title, int orient = wxHORIZONTAL)
		:type_array_ctrl<pcs_thrust_glow, glow_point_ctrl>(parent, Title, _(""), wxVERTICAL, wxEXPAND, ARRAY_ITEM)
	{
	}

	virtual~glow_point_array_ctrl(){}
};

```

## MOI.cpp

```cpp
#include "MOI.h"
#include <cmath>
#include <vector>
using namespace std;

void MOI::invert(){
	MOI dest;
	dest.a2d[0][0] = (-a2d[1][2]*a2d[2][1]+a2d[1][1]*a2d[2][2]);
	dest.a2d[0][1] = ( a2d[0][2]*a2d[2][1]-a2d[0][1]*a2d[2][2]);
	dest.a2d[0][2] = (-a2d[0][2]*a2d[1][1]+a2d[0][1]*a2d[1][2]);

	dest.a2d[1][0] = ( a2d[1][2]*a2d[2][0]-a2d[1][0]*a2d[2][2]);
	dest.a2d[1][1] = (-a2d[0][2]*a2d[2][0]+a2d[0][0]*a2d[2][2]);
	dest.a2d[1][2] = ( a2d[0][2]*a2d[1][0]-a2d[0][0]*a2d[1][2]);

	dest.a2d[2][0] = (-a2d[1][1]*a2d[2][0]+a2d[1][0]*a2d[2][1]);
	dest.a2d[2][1] = ( a2d[0][1]*a2d[2][0]-a2d[0][0]*a2d[2][1]);
	dest.a2d[2][2] = (-a2d[0][1]*a2d[1][0]+a2d[0][0]*a2d[1][1]);
	(*this) = dest;
}

MOI calc_cuboid_MOI(vector3d center, double xd, double yd, double zd){
	MOI ret;
	double m = 8.0*xd*yd*zd;
	ret.a2d[0][0] = (8/3*m*xd*yd*zd*((pow(yd,2)+3*pow(center.y,2)+pow(zd,2)+3*pow(center.z,2))));
	ret.a2d[1][1] = (8/3*m*xd*yd*zd*((pow(xd,2)+3*pow(center.x,2)+pow(zd,2)+3*pow(center.z,2))));
	ret.a2d[2][2] = (8/3*m*xd*yd*((pow(xd,2)+3*pow(center.x,2)+pow(yd,2)+3*pow(center.y,2)))*zd);
	ret.a2d[0][1] = 	ret.a2d[1][0] = 8*m*xd*center.x*yd*center.y*zd;
	ret.a2d[0][2] = 	ret.a2d[2][0] = 8*m*xd*center.x*yd*zd*center.z;
	ret.a2d[2][1] = 	ret.a2d[1][2] = 8*m*xd*yd*center.y*zd*center.z;

	
	return ret;
}

double minmax(vector3d tri[3], int coord, bool min){
	double ret = tri[0][coord];
	if(ret > tri[1][coord] && min)ret = tri[1][coord];
	if(ret > tri[2][coord] && min)ret = tri[2][coord];
	return ret;
}

MOI calc_under_tri(vector3d tri[3], int res){

	vector3d norm = CrossProduct(tri[0]-tri[1],tri[2]-tri[1]);
	vector3d pcenter = AverageVectors(3, tri);

	MOI ret;
	memset(&ret, 0,sizeof(MOI));
	if(norm.y == 0.0)return ret;

		double zmin = minmax(tri, 2, true);
	double zmax = minmax(tri, 2, false);

	int i;

	vector3d*top = &tri[0];
	for(i=1; i<3; i++){
		if(tri[i].z > top->z)
			top=&tri[i];
	}
	vector3d*bottom = &tri[0];
	for(i=1; i<3; i++){
		if(tri[i].z < bottom->z)
			bottom=&tri[i];
	}
	vector3d*mid = NULL;	for(i=0; i<3; i++){
		if(tri[i].z > bottom->z && tri[i].z < top->z )
			mid=&tri[i];
	}

	bool midpoint = mid!=NULL;
	if(!midpoint){
		mid = &tri[0];
		for(i=0; i<2; i++){
			if(tri[i] == *bottom || tri[i] == *top )
				mid=&tri[i++];
		}
	}

	

	for(int z =0; z<res; z++){
		double pz = zmin + (double(z+1)/double(res+1))*(zmax-zmin);
		
		vector3d*l, *r, *c;		bool lower = true;
				if(midpoint){
									if(mid->z < pz)
				lower = false;
		}else{
									if(mid->z < top->z)
				lower = false;
		}
		if(lower){
						if(top->x>mid->x){
				r=top;
				l=mid;
			}else{
				l=top;
				r=mid;
			}
			c=bottom;
		}else{
						if(bottom->x>mid->x){
				r=bottom;
				l=mid;
			}else{
				l=bottom;
				r=mid;
			}
			c=top;
		}		double ml, mr;		double cl, cr;
		ml = (l->x-c->x)/(l->z-c->z);
		mr = (c->x-r->x)/(c->z-r->z);

		cl = c->x -ml*c->z;
		cr = c->x -mr*c->z;

				
		double L, R;
		L = ml * pz +cl;
		R = mr * pz +cr;

		vector3d vol_cent; 
		vol_cent.x = float((L+R)/2.0);

		vol_cent.z = float(pz);

		bool s;		vol_cent.y = plane_line_intersect(pcenter, norm, vol_cent, vector3d(0.0f,1.0f,0.0f), &s).y/2.0f;

		if(s){
			ret += calc_cuboid_MOI(vol_cent, R-L, std::fabs(vol_cent.y*2.0f), pz);
		}
	}
	if(norm.y<0)
		ret.negate();
	return ret;
}

MOI calc_geometry_MOI(PCS_Model&model){
	return calc_cuboid_MOI(vector3d(0,0,0), 1, 1, 1);
	
	if(model.GetSOBJCount()<1)return MOI();

	int useable_model = 0;

	if(model.GetLODCount()>0){
		useable_model = model.LOD(0);
	}

	vector<pcs_polygon> &geometry = model.SOBJ(useable_model).polygons;

	MOI ret;
	memset(&ret, 0,sizeof(MOI));
	for(unsigned int i = 0; i<geometry.size(); i++ ){
		vector3d tri[3];
		tri[0] = geometry[i].verts[0].point;
		for(unsigned int j=1; j< geometry[i].verts.size()-1; j++){
			tri[1] = geometry[i].verts[j].point;
			tri[2] = geometry[i].verts[j+1].point;
			ret += calc_under_tri(tri, 10);
		}
	}

	return ret/model.GetMass();
}

```

## MOI.h

```cpp
#pragma once
#include "vector3d.h"
#include "pcs_file.h"

union MOI{
	double a2d[3][3];
	double a1d[9];

	MOI&operator = (const MOI&b){
		for(int i =0; i<9; i++){
			a1d[i] = b.a1d[i];
		}
		return *this;
	}
	void negate(){
		for(int i =0; i<9; i++){
			a1d[i] = -a1d[i];
		}
	}
	void invert();
};



inline MOI operator + (const MOI&a, const MOI&b){
	MOI ret;
	for(int i =0; i<9; i++){
		ret.a1d[i] = a.a1d[i] + b.a1d[i];
	}
	return ret;
}

inline MOI operator - (const MOI&a, const MOI&b){
	MOI ret;
	for(int i =0; i<9; i++){
		ret.a1d[i] = a.a1d[i] - b.a1d[i];
	}
	return ret;
}

inline MOI operator * (const MOI&a, const float b){
	MOI ret;
	for(int i =0; i<9; i++){
		ret.a1d[i] = a.a1d[i] * b;
	}
	return ret;
}

inline MOI operator / (const MOI&a, const float b){
	MOI ret;
	for(int i =0; i<9; i++){
		ret.a1d[i] = a.a1d[i] / b;
	}
	return ret;
}


inline MOI&operator += (MOI&a, const MOI&b){
	return a = a+b;
}

inline MOI&operator -= (MOI&a, const MOI&b){
	return a = a-b;
}

MOI calc_geometry_MOI(PCS_Model&model);
```

## pcs_file.cpp

```cpp


#if defined(_WIN32)
	#include <windows.h>
	#include <wx/msw/winundef.h>
#endif

#include "GLee.h"
#include <GL/glu.h>
#include "pcs_file.h"
#include "pcs_pof_bspfuncs.h"
#include <fstream>
#include <set>
#include <cfloat>
#include "color.h"
#include "omnipoints.h"
#include <wx/msgdlg.h>

unsigned int PCS_Model::BSP_MAX_DEPTH = 0;
unsigned int PCS_Model::BSP_CUR_DEPTH = 0;
unsigned int PCS_Model::BSP_NODE_POLYS = 1;
bool PCS_Model::BSP_COMPILE_ERROR = false;
wxLongLong PCS_Model::BSP_TREE_TIME = 0;

bool PCS_Model::split_poly(std::vector<pcs_polygon>&polys, int I, int i, int j){

	if(i>j){
				int temp = i;
		i=j;
		j=temp;
	}

	if(polys[I].verts.size() < 4 ||
		i==j ||
		j-i<2 || (i==0 && (unsigned)j == polys[I].verts.size()-1)){
			return false;
		wxMessageBox(_("*ERROR*:bad split attempted! \n\nOH NOE NOT THAT!."), _("in an emergency, your seat cusion may be used as a flotation device"));
	}


	polys.push_back(polys[I]);
		pcs_polygon&split1 = polys[I];
	pcs_polygon&split2 = polys[polys.size()-1];

		int h;
		for(h = 0; h<i; h++)
		split1.verts.erase(split1.verts.begin());
	split1.verts.resize(j-i+1);

		for(h = i+1; h<j; h++)
		split2.verts.erase(split2.verts.begin()+(i+1));

		vector3d norm(0,0,0);

	for(h = 0; h<(int)split1.verts.size(); h++)
		norm = norm + CrossProduct(split1.verts[(h+split1.verts.size()-1)%split1.verts.size()].point-split1.verts[h].point, split1.verts[(h+1)%split1.verts.size()].point-split1.verts[h].point);
	split1.norm = MakeUnitVector(norm);
	norm = vector3d(0,0,0);

	for(h = 0; h<(int)split2.verts.size(); h++)
		norm = norm + CrossProduct(split2.verts[(h+split2.verts.size()-1)%split2.verts.size()].point-split2.verts[h].point, split2.verts[(h+1)%split2.verts.size()].point-split2.verts[h].point);
	split2.norm = MakeUnitVector(norm );
	
	return true;
}

bool closest_line_pt(vector3d l1p1, vector3d l1p2, vector3d l2p1, vector3d l2p2, vector3d*closest1 = NULL, vector3d*closest2 = NULL){

	vector3d ln1 = MakeUnitVector(l1p2-l1p1);
	vector3d ln2 = MakeUnitVector(l2p2-l2p1);

	vector3d In = CrossProduct(ln1,ln2);

	vector3d pnA = MakeUnitVector(CrossProduct(ln1,In));
	vector3d pnB = MakeUnitVector(CrossProduct(ln2,In));

	float d;
	
	d = dot(pnB,ln1);
	if(d==0.0f)return true;
	float tA = -dot(pnB,l1p1-l2p1)/d;

	d = dot(pnA,ln2);
	if(d==0.0f)return true;
	float tB = -dot(pnA,l2p1-l1p1)/d;

	if(closest1){
	   (*closest1) = l1p1+ln1*tA;
	}
	if(closest2){
	   (*closest2) = l2p1+ln2*tB;
	}
	if(tA<0.0f || tB<0.0f || Distance(l1p1,l1p2) < tA || Distance(l2p1,l2p2) < tB)
		return true;
	else
		return false;
}

float full_angle(vector3d A, vector3d B, vector3d C, vector3d pln){
	A = MakeUnitVector(A-C);
	B = MakeUnitVector(B-C);

	float ang = acos(dot(A,B));

	if(dot(CrossProduct(B,A),pln) > 0)
		ang = M_PI*2.0f - ang;

	return ang;
}

void interconect_poly_on_verts(std::vector<pcs_polygon>&polys, int i, std::vector<unsigned int>&concaves, vector3d&pnorm){
	
	pcs_polygon&poly = polys[i];
	const unsigned int psize = polys[i].verts.size();

		if(concaves.size() == 1){
									
									
			
			
			if(PCS_Model::split_poly(polys, i, concaves[0], (concaves[0]+poly.verts.size()/2)%poly.verts.size())){
				PCS_Model::filter_polygon(polys, i);
							}
		}else if(concaves.size() > 1){
									unsigned int s;
			unsigned int t;
			for(s = 0; s < concaves.size(); s++){
					vector3d&sth = poly.verts[concaves[s]].point;
					vector3d&sthm1 = poly.verts[(concaves[s]-1+poly.verts.size())%poly.verts.size()].point;
					vector3d&sthp1 = poly.verts[(concaves[s]+1)%poly.verts.size()].point;
				for(t = s+1; t < concaves.size(); t++){
					if((concaves[s]+1)%poly.verts.size() == concaves[t] || (concaves[t]+1)%poly.verts.size() == concaves[s])
						continue;

					vector3d&tth = poly.verts[concaves[t]].point;

										float  ang = full_angle(sthm1, sthp1, sth,pnorm);
					float tang = full_angle(sthm1, tth, sth,pnorm);
					if(tang<=ang)
						continue;
										
																				unsigned int j;
					for(j = 0; j < poly.verts.size(); j++){
						vector3d test1, test2;
						if(concaves[s] == j || concaves[s] == (j+1)%psize || concaves[t] == j || concaves[t] == (j+1)%psize)
							continue;
						if(!closest_line_pt(poly.verts[j].point, poly.verts[(j+1)%poly.verts.size()].point, sth, tth, &test1, &test2))
						 break;
					}
					if(j == poly.verts.size())break;
				}
				if(t < concaves.size())break;
			}

						if(s < concaves.size()){
				if(PCS_Model::split_poly(polys, i, concaves[s], concaves[t])){
					PCS_Model::filter_polygon(polys, i);
									}
			}else{
												for(s = 0; s < concaves.size(); s++){
					vector3d&sth = poly.verts[concaves[s]].point;
					vector3d&sthm1 = poly.verts[(concaves[s]-1+poly.verts.size())%poly.verts.size()].point;
					vector3d&sthp1 = poly.verts[(concaves[s]+1)%poly.verts.size()].point;
					unsigned int T;
					for(T = 0; T < poly.verts.size()-1; T++){
						t = (T+concaves[s]+2)%poly.verts.size();

						if((concaves[s]+1)%poly.verts.size() == t || (t+1)%poly.verts.size() == concaves[s])
							continue;

						vector3d&tth = poly.verts[t].point;

												float  ang = full_angle(sthm1, sthp1, sth,pnorm);
						float tang = full_angle(sthm1, tth, sth,pnorm);
						if(tang<=ang)
							continue;
												
																								unsigned int j;
						for(j = 0; j < poly.verts.size(); j++){
							if(concaves[s] == j || concaves[s] == (j+1)%psize || t == j || t == (j+1)%psize)
								continue;
							vector3d&jth = poly.verts[j].point;
														vector3d&jthp1 = poly.verts[(j+1)%poly.verts.size()].point;
							if(!closest_line_pt(jth, jthp1, sth, tth))
								break;
						}
												if(j == poly.verts.size())break;
					}
										if(T < poly.verts.size()-1)break;
				}
				if(s < concaves.size()){
										if(PCS_Model::split_poly(polys, i, concaves[s], t)){
						PCS_Model::filter_polygon(polys, i);
											}
				}else{
										wxMessageBox(_("*ERROR*:uncorectable geometry encountered! \n\nTruly this is the darkest of hours."), _("Think about the CHILDREN damnit!!!!!!!"));
				}
			}
		}
}

void PCS_Model::filter_polygon(std::vector<pcs_polygon>&polys, int i){

		if(polys[i].verts.size() < 4)return;
		
		pcs_polygon&poly = polys[i];

		unsigned int psize = polys[i].verts.size();

		vector3d avg(0,0,0);
		for(unsigned int j = 0; j<psize; j++){
			avg += poly.verts[j].point;
		}
		avg = avg/psize;

		std::vector<vector3d> norms(psize);
		vector3d pnorm;
		for(unsigned int j = 0; j<psize; j++){
			norms[j] = CrossProduct(
				poly.verts[(j+1)%poly.verts.size()].point					-poly.verts[j].point, 
				poly.verts[(j-1+poly.verts.size())%poly.verts.size()].point	-poly.verts[j].point);
			if(!no_nan(norms[j])){
				norms[j] = vector3d(0,0,0);
			}
			pnorm += norms[j];
			norms[j] = MakeUnitVector(norms[j]);
		}
		pnorm = MakeUnitVector(pnorm);



		
		std::vector<unsigned int> concaves;

				for(unsigned int j = 0; j<psize; j++){
			if(dot(norms[j], pnorm)<=0.0f){
								concaves.push_back(j);
			}
		}

		interconect_poly_on_verts(polys, i, concaves, pnorm);

				

		psize = polys[i].verts.size();

		norms.resize(psize);
				for(unsigned int j = 0; j<psize; j++){
			norms[j] = CrossProduct(
				polys[i].verts[(j+1)%polys[i].verts.size()].point					-polys[i].verts[j].point, 
				polys[i].verts[(j-1+polys[i].verts.size())%polys[i].verts.size()].point	-polys[i].verts[j].point);
			if(!no_nan(norms[j])){
				norms[j] = vector3d(0,0,0);
			}
			pnorm += norms[j];
			norms[j] = MakeUnitVector(norms[j]);
		}

		pnorm = MakeUnitVector(pnorm);
		std::vector<unsigned int>&nonplanar = concaves;		nonplanar.resize(0);

				for(unsigned int j = 0; j<psize; j++){
			if(dot(norms[j], pnorm)<=0.999f){
								nonplanar.push_back(j);
			}
		}

		interconect_poly_on_verts(polys, i, nonplanar, pnorm);


		if(polys[i].verts.size() > 20){
						if(split_poly(polys, i, 0, poly.verts.size()/2)){
				filter_polygon(polys, i);
							}
			return;
		}
}

void PCS_Model::filter_geometry(std::vector<pcs_polygon>&polys){
	for(unsigned int i = 0; i< polys.size(); i++){
		filter_polygon(polys, i);
	}
}

#define PCS_ADD_TO_VEC(vec, var) unsigned int idx = vec.size(); \
								 vec.resize(idx+1); \
								 if (var) \
									vec[idx] = *var;


int PCS_Model::LoadFromPMF(std::string filename, AsyncProgress* progress)
{
	this->Reset();
	progress->setTarget(17);
	std::ifstream in(filename.c_str(), std::ios::in | std::ios::binary);
	if (!in)
		return 1;

	progress->incrementWithMessage("Checking Filesig");
		char sig[] = { 'P', 'M', 'F', '1' }, fs[4];
	int ver;

	in.read(fs, 4);
	if (strncmp(fs, sig, 4))
		return 2; 	BFRead(ver, int)

	if (ver < PMF_MIN_VERSION || ver > PMF_MAX_VERSION)
		return 3; 	
	progress->incrementWithMessage("Reading Header");

	BFRead(header.max_radius, float)
	BFRead(header.min_bounding, vector3d)
	BFRead(header.max_bounding, vector3d)
	header.max_radius_override = header.max_radius;
	header.min_bounding_override = header.min_bounding;
	header.max_bounding_override = header.max_bounding;
	BFReadVector(header.detail_levels)
	BFReadVector(header.debris_pieces)
	BFRead(header.mass, float)
	BFRead(header.mass_center, vector3d)
	in.read((char*)header.MOI, sizeof(float)*9);
	BFReadVector(header.cross_sections)
	BFRead(autocentering, vector3d)

	progress->incrementWithMessage("Reading Textures");

	unsigned int i;
	BFRead(i, int)
	textures.resize(i);
	for (i = 0; i < textures.size(); i++)
		BFReadString(textures[i])

	progress->incrementWithMessage("Reading Subobjects");
	BFReadAdvVector(subobjects)

	progress->incrementWithMessage("Reading Info Strings");
	BFRead(i, int)
	model_info.resize(i);
	for (i = 0; i < model_info.size(); i++)
		BFReadString(model_info[i])

	progress->incrementWithMessage("Reading Eyes");
	BFReadVector(eyes)

	progress->incrementWithMessage("Reading Specials");
	BFReadAdvVector(special)

	progress->incrementWithMessage("Reading Weapons");
	BFReadAdvVector(weapons)

	progress->incrementWithMessage("Reading Turrets");
	BFReadAdvVector(turrets)

	progress->incrementWithMessage("Reading Docking");
	BFReadAdvVector(docking)

	progress->incrementWithMessage("Reading Thrusters");
	BFReadAdvVector(thrusters)

	progress->incrementWithMessage("Reading Shields");
	BFReadVector(shield_mesh)

	progress->incrementWithMessage("Reading Insignia");
	BFReadAdvVector(insignia)

	progress->incrementWithMessage("Reading Paths");
	BFReadAdvVector(ai_paths)

	progress->incrementWithMessage("Reading Glows");
	BFReadAdvVector(light_arrays)
	
	progress->incrementWithMessage("Reading BSP Cache");
	if (ver >= 102)
	{
		BFReadAdvVector(bsp_cache)
		BFRead(can_bsp_cache, bool)
		if (ver == 102) {
						can_bsp_cache = false;
		}

				BFRead(has_fullsmoothing_data, bool)
		
	}
	Transform(matrix(), vector3d());
	header.max_radius_overridden = header.max_radius_override != header.max_radius;
	header.min_bounding_overridden = header.min_bounding_override != header.min_bounding;
	header.max_bounding_overridden = header.max_bounding_override != header.max_bounding;
	for (auto& sobj : subobjects) {
		sobj.radius_overridden = std::fabs(sobj.radius - sobj.radius_override) > 0.0001f;
		sobj.bounding_box_min_point_overridden = sobj.bounding_box_min_point != sobj.bounding_box_min_point_override;
		sobj.bounding_box_max_point_overridden = sobj.bounding_box_max_point != sobj.bounding_box_max_point_override;
	}

	progress->incrementProgress();

	return 0;
}

	
int PCS_Model::SaveToPMF(std::string filename, AsyncProgress* progress)
{
	progress->setTarget(17);

	std::ofstream out(filename.c_str(), std::ios::out | std::ios::binary);
	if (!out)
		return 1;

	progress->incrementWithMessage("Writing Filesig");
		char sig[] = { 'P', 'M', 'F', '1' };
	int ver = PMF_VERSION;

	out.write(sig, 4);
	BFWrite(ver, int)

	progress->incrementWithMessage("Writing Header");
	
	BFWrite(header.max_radius_overridden ? header.max_radius_override : header.max_radius, float);
	BFWrite(header.min_bounding_overridden ? header.min_bounding_override : header.min_bounding, vector3d);
	BFWrite(header.max_bounding_overridden ?  header.max_bounding_override : header.max_bounding, vector3d);
	BFWriteVector(header.detail_levels)
	BFWriteVector(header.debris_pieces)
	BFWrite(header.mass, float)
	BFWrite(header.mass_center, vector3d)
	out.write((char*)header.MOI, sizeof(float)*9);
	BFWriteVector(header.cross_sections)
	BFWrite(autocentering, vector3d)


	progress->incrementWithMessage("Writing Textures");
	unsigned int i = textures.size();
	BFWrite(i, int)
	for (i = 0; i < textures.size(); i++)
		BFWriteString(textures[i])

	
	progress->incrementWithMessage("Writing Subobjects");
	BFWriteAdvVector(subobjects)
	
	progress->incrementWithMessage("Writing Info Strings");
	i = model_info.size();
	BFWrite(i, int)
	for (i = 0; i < model_info.size(); i++)
		BFWriteString(model_info[i])

	progress->incrementWithMessage("Writing Eyes");
	BFWriteVector(eyes)

	progress->incrementWithMessage("Writing Special");
	BFWriteAdvVector(special)

	progress->incrementWithMessage("Writing Weapons");
	BFWriteAdvVector(weapons)

	progress->incrementWithMessage("Writing Turrets");
	BFWriteAdvVector(turrets)

	progress->incrementWithMessage("Writing Docking");
	BFWriteAdvVector(docking)

	progress->incrementWithMessage("Writing Thrusters");
	BFWriteAdvVector(thrusters)

	progress->incrementWithMessage("Writing Shields");
	BFWriteVector(shield_mesh)

	progress->incrementWithMessage("Writing Insignia");
	BFWriteAdvVector(insignia)

	progress->incrementWithMessage("Writing Paths");
	BFWriteAdvVector(ai_paths)

	progress->incrementWithMessage("Writing Glows");
	BFWriteAdvVector(light_arrays)

	progress->incrementWithMessage("Writing BSP Cache");
	BFWriteAdvVector(bsp_cache)
	BFWrite(can_bsp_cache, bool)

	
	BFWrite(has_fullsmoothing_data, bool)

	progress->incrementProgress();
	return 0;
}


void PCS_Model::Reset()
{
		active_submodel = 0;
	active_texture = -1;
	highlight_active_model = false;
			can_bsp_cache = false;
	has_fullsmoothing_data = false;
	vbos_enabled = false;

	
	header.max_radius = 0;

	autocentering = header.mass_center = header.min_bounding = header.max_bounding = vector3d(0,0,0);

	header.detail_levels.resize(0);
	header.debris_pieces.resize(0);
	header.mass = 0.0;

	memset(header.MOI, 0, sizeof(float) * 9);

	for (size_t i = 0; i < subobjects.size(); i++)
		subobjects[i].destroy_vertex_buffer();

	header.cross_sections.resize(0);
	textures.resize(0);
	subobjects.resize(0);
	model_info.resize(0);
	eyes.resize(0);
	special.resize(0);
	weapons.resize(0);
	turrets.resize(0);
	docking.resize(0);
	thrusters.resize(0);
	shield_mesh.resize(0);
	insignia.resize(0);
	ai_paths.resize(0);
	light_arrays.resize(0);

	bsp_cache.resize(0);

}


float PCS_Model::GetMaxRadius()
{
	return header.max_radius;
}


float PCS_Model::GetMass()
{
	return header.mass;
}


void PCS_Model::GetMOI(std::vector<float>& tensor)
{
	for (int i = 0; i < 3; i++)
		for (int j = 0; j < 3; j++)
			tensor[(3 * i) + j] = header.MOI[i][j];
}



vector3d PCS_Model::GetMinBounding()
{
	return header.min_bounding;
}


vector3d PCS_Model::GetMaxBounding()
{
	return header.max_bounding;
}


vector3d PCS_Model::GetCenterOfMass()
{
	return header.mass_center;
}


vector3d PCS_Model::GetAutoCenter()
{
	return autocentering;
}



std::string& PCS_Model::ModelInfo(unsigned int idx)
{
	return model_info[idx];
}




int PCS_Model::GetLODCount()
{
	return header.detail_levels.size();
}


int PCS_Model::GetDebrisCount()
{
	return header.debris_pieces.size();
}


int PCS_Model::GetCrossSectCount()
{
	return header.cross_sections.size();
}


int PCS_Model::GetTexturesCount()
{
	return textures.size();
}


int PCS_Model::GetSOBJCount()
{
	return subobjects.size();
}


int PCS_Model::GetEyeCount()
{
	return eyes.size();
}


int PCS_Model::GetSpecialCount()
{
	return special.size();
}


int PCS_Model::GetWeaponCount()
{
	return weapons.size();
}


int PCS_Model::GetTurretCount()
{
	return turrets.size();
}


int PCS_Model::GetDockingCount()
{
	return docking.size();
}


int PCS_Model::GetThrusterCount()
{
	return thrusters.size();
}


int PCS_Model::GetShldTriCount()
{
	return shield_mesh.size();
}


int PCS_Model::GetInsigniaCount()
{
	return insignia.size();
}


int PCS_Model::GetPathCount()
{
	return ai_paths.size();
}


int PCS_Model::GetLightCount()
{
	return light_arrays.size();
}



int&					PCS_Model::LOD			(unsigned int idx)
{
	return header.detail_levels[idx];
}


int&					PCS_Model::Debris		(unsigned int idx)
{
	return header.debris_pieces[idx];
}


pcs_crs_sect&			PCS_Model::CrossSect	(unsigned int idx)
{
	return header.cross_sections[idx];
}


std::string&			PCS_Model::Texture		(unsigned int idx)
{
	return textures[idx];
}


pcs_sobj&				PCS_Model::SOBJ		(unsigned int idx)
{
	return subobjects[idx];
}


pcs_eye_pos&			PCS_Model::Eye			(unsigned int idx)
{
	return eyes[idx];
}


pcs_special&			PCS_Model::Special		(unsigned int idx)
{
	return special[idx];
}


pcs_slot&				PCS_Model::Weapon		(unsigned int idx)
{
	return weapons[idx];
}


pcs_turret&				PCS_Model::Turret		(unsigned int idx)
{
	return turrets[idx];
}


pcs_dock_point&			PCS_Model::Dock		(unsigned int idx)
{
	return docking[idx];
}


pcs_thruster&			PCS_Model::Thruster	(unsigned int idx)
{
	return thrusters[idx];
}


pcs_shield_triangle&	PCS_Model::ShldTri		(unsigned int idx)
{
	return shield_mesh[idx];
}


pcs_insig&				PCS_Model::Insignia	(unsigned int idx)
{
	return insignia[idx];
}


pcs_path&				PCS_Model::Path		(unsigned int idx)
{
	return ai_paths[idx];
}


pcs_glow_array&			PCS_Model::Light		(unsigned int idx)
{
	return light_arrays[idx];
}



void PCS_Model::SetMaxRadius(float rad)
{
	header.max_radius = rad;
}


void PCS_Model::SetMass(float mass)
{
	this->header.mass = mass;
}


void PCS_Model::SetMOI(float tensor[3][3])
{
	for (int i = 0; i < 3; i++)
		for (int j = 0; j < 3; j++)
			header.MOI[i][j] = tensor[i][j];
}



void PCS_Model::SetMinBounding(const vector3d &bnd)
{
	header.min_bounding = bnd;
}


void PCS_Model::SetMaxBounding(const vector3d &bnd)
{
	header.max_bounding = bnd;
}


void PCS_Model::SetCenterOfMass(const vector3d &cnt)
{
	header.mass_center = cnt;
}


void PCS_Model::SetAutoCenter(const vector3d &cnt)
{
	autocentering = cnt;
}


void PCS_Model::AddModelInfo(std::string info)
{
		model_info.push_back(info);
}



void PCS_Model::SetModelInfo(unsigned int idx, std::string info)
{
	model_info[idx] = info;
}



void PCS_Model::AddLOD(int sobj)
{
	header.detail_levels.push_back(sobj);
}


void PCS_Model::DelLOD(unsigned int idx)
{
	RemoveIndex(header.detail_levels, idx);
}


void PCS_Model::AddDebris(int sobj)
{
	header.debris_pieces.push_back(sobj);
}


void PCS_Model::DelDebris(unsigned int idx)
{
	RemoveIndex(header.debris_pieces, idx);
}



void PCS_Model::AddCrossSect(pcs_crs_sect *cs)
{
	PCS_ADD_TO_VEC(header.cross_sections, cs)
}


void PCS_Model::DelCrossSect(unsigned int idx)
{
	RemoveIndex(header.cross_sections, idx);
}


int PCS_Model::maybeAddTexture(std::string txt)
{
	int index = FindInList<std::string>(textures, txt);
	if (index != -1)
		return index;
	index = textures.size();
	textures.push_back(txt);
	return index;
}


void PCS_Model::AddTextures(std::string txt)
{
				textures.push_back(txt);
}


void PCS_Model::DelTextures(unsigned int idx)
{
	RemoveIndex(textures, idx);
}



void PCS_Model::AddSOBJ(pcs_sobj *obj)
{
	pmf_bsp_cache cache;
	cache.decache();
	bsp_cache.push_back(cache);
	if (obj)
		subobjects.push_back(*obj);
	else
	{
		pcs_sobj empty;
		subobjects.push_back(empty);
	}
	if (vbos_enabled) {
		subobjects.back().vertex_buffer.clear();
		subobjects.back().line_vertex_buffer.clear();
		make_vertex_buffer(subobjects.size() - 1);
	}
}


void PCS_Model::DelSOBJ(int idx)
{
		
		unsigned int i;
	for(i = 0; i<subobjects.size(); i++){
		if(subobjects[i].parent_sobj == idx)
			subobjects[i].parent_sobj=subobjects[idx].parent_sobj;		if(subobjects[i].parent_sobj > (int)idx)
			subobjects[i].parent_sobj--;	}

		for(i = 0; i<header.detail_levels.size(); i++){
		if(header.detail_levels[i] == idx)
			header.detail_levels.erase(header.detail_levels.begin()+i);		if(i>=header.detail_levels.size())
			break;		if(header.detail_levels[i] > (int)idx)
			header.detail_levels[i]--;	}
		for(i = 0; i<header.debris_pieces.size(); i++){
		if(header.debris_pieces[i] == idx)
			header.debris_pieces.erase(header.debris_pieces.begin()+i);		if(i>=header.debris_pieces.size())
			break;		if(header.debris_pieces[i] > (int)idx)
			header.debris_pieces[i]--;	}
	for(i = 0; i<turrets.size(); i++){
		if(turrets[i].sobj_par_phys == idx)
			turrets[i].sobj_par_phys = turrets[i].sobj_parent;
		if(turrets[i].sobj_par_phys > (int)idx)
			turrets[i].sobj_par_phys--;

		if(turrets[i].sobj_parent == idx)
			turrets.erase(turrets.begin()+i);		if(i>=turrets.size())
			break;		if(turrets[i].sobj_parent > (int)idx)
			turrets[i].sobj_parent--;	}
	for(i = 0; i<eyes.size(); i++){
		if(eyes[i].sobj_number == idx)
			eyes[i].sobj_number = subobjects[idx].parent_sobj;
		if(i>=eyes.size())
			break;		if(eyes[i].sobj_number > (int)idx)
			eyes[i].sobj_number--;
	}
	for(i = 0; i<light_arrays.size(); i++){
		if(light_arrays[i].obj_parent == idx)
			light_arrays[i].obj_parent = subobjects[idx].parent_sobj;
		if(i>=light_arrays.size())
			break;		if(light_arrays[i].obj_parent > (int)idx)
			light_arrays[i].obj_parent--;
	}

		if(active_submodel == idx)
		active_submodel = subobjects[idx].parent_sobj;
	if(active_submodel > (int)idx)
		active_submodel--;
	if(active_submodel < 0 && header.detail_levels.size() > 0)
		active_submodel = header.detail_levels[0];

	if (bsp_cache.size() > (unsigned)idx) {
		bsp_cache.erase(bsp_cache.begin() + idx);
	}
	RemoveIndex(subobjects, idx);
}

		
void PCS_Model::SetObjectChanged(unsigned int idx)
{
	if (idx >= subobjects.size())
		return;

	if (vbos_enabled) {
		make_vertex_buffer(idx);
	}
	if (can_bsp_cache)
		bsp_cache[idx].changed = true;
}



void PCS_Model::AddEye(pcs_eye_pos *eye)
{
	PCS_ADD_TO_VEC(eyes, eye)
}


void PCS_Model::DelEye(unsigned int idx)
{
	RemoveIndex(eyes, idx);
}



void PCS_Model::AddSpecial(pcs_special *spcl)
{
	PCS_ADD_TO_VEC(special, spcl)
}


void PCS_Model::DelSpecial(unsigned int idx)
{
	RemoveIndex(special, idx);
}



void PCS_Model::AddWeapon(pcs_slot *weap)
{
	PCS_ADD_TO_VEC(weapons, weap)
}


void PCS_Model::DelWeapon(unsigned int idx)
{
	RemoveIndex(weapons, idx);
}



void PCS_Model::AddTurret(pcs_turret *trrt)
{
	turrets.push_back(*trrt);
	}


void PCS_Model::DelTurret(unsigned int idx)
{
	RemoveIndex(turrets, idx);
}


void PCS_Model::AddDocking(pcs_dock_point *dock)
{
	PCS_ADD_TO_VEC(docking, dock)
}


void PCS_Model::DelDocking(unsigned int idx)
{
	RemoveIndex(docking, idx);
}



void PCS_Model::AddThruster(pcs_thruster *thrust)
{
	PCS_ADD_TO_VEC(thrusters, thrust)
}


void PCS_Model::DelThruster(unsigned int idx)
{
	RemoveIndex(thrusters, idx);
}



void PCS_Model::AddShldTri(pcs_shield_triangle *stri)
{
	PCS_ADD_TO_VEC(shield_mesh, stri)
}


void PCS_Model::DelShldTri(unsigned int idx)
{
	RemoveIndex(shield_mesh, idx);
}



void PCS_Model::AddInsignia(pcs_insig *insig)
{
	PCS_ADD_TO_VEC(insignia, insig)
}


void PCS_Model::DelInsignia(unsigned int idx)
{
	RemoveIndex(insignia, idx);
}



void PCS_Model::AddPath(pcs_path *path)
{
	PCS_ADD_TO_VEC(ai_paths, path)
}


void PCS_Model::DelPath(unsigned int idx)
{
	RemoveIndex(ai_paths, idx);
}



void PCS_Model::AddLight(pcs_glow_array *lights)
{
	PCS_ADD_TO_VEC(light_arrays, lights)
}


void PCS_Model::DelLight(unsigned int idx)
{
	RemoveIndex(light_arrays, idx);
}



void PCS_Model::Calculate_Smoothing_Data(int &sobjs_comp)
{
	std::vector<std::vector<int> > covertals; 	unsigned int i, j, k, l, m, cvc;
	bool tBool;	vector3d tvect;	pcs_sobj *sobj;
		if (has_fullsmoothing_data) return;

	sobjs_comp = 0;
	for (i =0; i < this->subobjects.size(); i++) 	{
		sobj = &this->subobjects[i];
		for (j = 0; j < sobj->polygons.size(); j++) 		{

						tBool = true;
			for (k = 0; k < sobj->polygons[j].verts.size() && tBool == true; k++)
			{
				tBool = tBool && (sobj->polygons[j].norm == sobj->polygons[j].verts[k].norm);
			}
			if (tBool) 
			{
								for (k = 0; k < sobj->polygons[j].verts.size(); k++)
					sobj->polygons[j].verts[k].facet_angle = 0;
				continue;
			}

						covertals.resize(sobj->polygons[j].verts.size());
			for (k = 0; k < sobj->polygons[j].verts.size(); k++) 			{
				cvc=0;
				covertals[k].resize(10); 
				for (l = 0; l < sobj->polygons.size(); l++) 				{
					if (l == j)
						continue; 
					for (m = 0; m < sobj->polygons[l].verts.size(); m++) 					{
						if (sobj->polygons[j].verts[k].point == sobj->polygons[l].verts[m].point)
						{
							covertals[k][cvc] = l;
							cvc++;

							if (cvc >= covertals[k].size())
									covertals[k].resize(cvc * 2);
						}
					} 				} 
				covertals[k].resize(cvc);
			} 
			
						tBool = true;
			for (k = 0; k < sobj->polygons[j].verts.size() && tBool == true; k++)
			{
				tvect = sobj->polygons[j].norm;

				for (l = 0; l < covertals[k].size(); l++)
				{
					tvect += sobj->polygons[covertals[k][l]].norm;
				}
				tvect = tvect/(1+covertals[k].size());
				tBool = tBool && (tvect == sobj->polygons[j].verts[k].norm);
			}
			if (tBool) 
			{
								for (k = 0; k < sobj->polygons[j].verts.size(); k++)
					sobj->polygons[j].verts[k].facet_angle = -1;
				continue;
			}

						
			for (k = 0; k < sobj->polygons[j].verts.size(); k++)
				sobj->polygons[j].verts[k].facet_angle = 32;

												

		} 
		sobjs_comp++;
	} 
	has_fullsmoothing_data = true;
}





void PCS_Model::draw_shields(){
	glDisable(GL_TEXTURE_2D);
	glEnable(GL_LIGHTING);
	glEnable(GL_BLEND);
	
	glBlendFunc(GL_ONE,GL_ONE);
	glDisable(GL_CULL_FACE);

	glDepthMask(GL_FALSE);

	float light_one[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	float light_zero[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
	glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE, light_zero );
	glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR, light_one );
	glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 65.0f );

	glBegin(GL_TRIANGLES);
	glColor4ubv( (GLubyte*)(get_SHLD_color()*0.25f).col);

	for (unsigned int i = 0; i < shield_mesh.size(); i++)
	{
		for (unsigned int j = 0; j < 3; j++)
		{
			glNormal3fv((GLfloat *) &shield_mesh[i].face_normal);
			glVertex3fv((GLfloat *) &shield_mesh[i].corners[j]);
		}
	}
	glEnd();

	glDisable(GL_BLEND);
	glDisable(GL_LIGHTING);
	glDisable(GL_TEXTURE_2D);
	glColor4ubv( (GLubyte*)get_SHLD_color().col);

	for (unsigned int i = 0; i < shield_mesh.size(); i++)
	{
		glBegin(GL_LINE_STRIP);

		for (unsigned int j = 0; j < 3; j++)
		{
			glVertex3fv((GLfloat *) &shield_mesh[i].corners[j]);
		}

				glVertex3fv((GLfloat *) &shield_mesh[i].corners[0]);

		glEnd();
	}
	glDepthMask(GL_TRUE);

}


void PCS_Model::draw_insignia(int lod, const omnipoints& omni){
	if (Wireframe) {
		return;
	}
	glColor4f(1.0, 1.0, 1.0, 1.0); 
	glDisable(GL_LIGHTING);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_ALPHA_TEST);
	glAlphaFunc(GL_GREATER, 0.01f);
	glDisable(GL_CULL_FACE);
	ERROR_CHECK;
	if (!Textureless) {
		glActiveTexture(GL_TEXTURE0);
		glEnable(GL_TEXTURE_2D);
		glBindTexture(GL_TEXTURE_2D, 1);
				glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
		glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, GL_PRIMARY_COLOR);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_TEXTURE);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
		glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE, 1.0f);
	} else {
		glActiveTexture(GL_TEXTURE0);
		glDisable(GL_TEXTURE_2D);
	}

	for (unsigned int i = 0; i < insignia.size(); i++)
	{
		pcs_insig& insig = insignia[i];
		if (lod == insig.lod) {
			for (unsigned int j = 0; j < insig.faces.size(); j++) {
				pcs_insig_face& face = insig.faces[j];
				glBegin(GL_POLYGON);
				for (unsigned int k = 0; k < 3; k++)
				{
					vector3d offsetted(face.verts[k] + insig.offset);
					if (!Textureless) {
						glTexCoord2f(face.u[k], face.v[k]);
					}
					glVertex3fv((GLfloat *) &offsetted);
				}
				glEnd();
				ERROR_CHECK;
			}
		}
	}
	if (omni.point.size() == 2 && omni.point[0].size() == 1 && omni.point[1].size() == 4) {
			glBegin(GL_POLYGON);
			if (!Textureless) {
				glTexCoord2f(0.0f, 0.0f);
			}
			glVertex3fv((GLfloat *) &omni.point[1][0]);
			if (!Textureless) {
				glTexCoord2f(1.0f, 0.0f);
			}
			glVertex3fv((GLfloat *) &omni.point[1][1]);
			if (!Textureless) {
				glTexCoord2f(1.0f, 1.0f);
			}
			glVertex3fv((GLfloat *) &omni.point[1][2]);
			if (!Textureless) {
				glTexCoord2f(0.0f, 1.0f);
			}
			glVertex3fv((GLfloat *) &omni.point[1][3]);
			glEnd();
			ERROR_CHECK;
	}

	glDisable(GL_BLEND);
	glDisable(GL_TEXTURE_2D);
	glColor4ubv( (GLubyte*)get_SHLD_color().col);

	glDepthMask(GL_TRUE);

}


void PCS_Model::Render(TextureControl &tc, bool use_vbos, bool highlight)
{
	if (header.detail_levels.size() < 1)
		return; 
	int render_root = find_LOD_root(active_submodel);

	if ((unsigned)render_root > subobjects.size() || render_root < 0)
		return; 
	glTranslatef(-autocentering.x, -autocentering.y, -autocentering.z);

	highlight_active_model = highlight;


	if(is_debris(render_root)){
		for(unsigned int i = 0; i<header.debris_pieces.size(); i++){
			RenderGeometryRecursive(header.debris_pieces[i], tc, use_vbos);
		}
	}else{
		RenderGeometryRecursive(render_root, tc, use_vbos);
	}

}



void PCS_Model::RenderGeometryRecursive(int sobj, TextureControl &tc, bool use_vbos)
{
	bool vertex_buffers = GLEE_ARB_vertex_buffer_object == GL_TRUE; 									 
	float light_one[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	float light_zero[4] = { 0.0f, 0.0f, 0.0f, 1.0f };

	vector3d trans = subobjects[sobj].offset; 		ERROR_CHECK;

	glTranslatef(trans.x, trans.y, trans.z);

		unsigned int i;
	std::string name;
	for (i = 0; i < subobjects.size(); i++)
	{
		name = strLower(subobjects[i].name.c_str());
	
		if (subobjects[i].parent_sobj == sobj && 
			strstr(name.c_str(), "-destroyed") == NULL)
			RenderGeometryRecursive(i, tc, use_vbos);
	}
		

	if(vertex_buffers && use_vbos){
		RenderGeometry_vertex_buffers(sobj, tc);
	}else{
				glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE, light_one );
		glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR, light_zero );
			std::vector<pcs_polygon> &polygons = subobjects[sobj].polygons;
				int tex_id = -1, glow_tex_id = -1, shine_tex_id = -1;
		glColor4f(1.0, 1.0, 1.0, 1.0); 
		if (!Wireframe)
		{
			glEnable(GL_LIGHTING);
			glEnable(GL_BLEND);
			glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
			glEnable(GL_ALPHA_TEST);
			glAlphaFunc(GL_GREATER, 0.01f);
		}
		else
		{
			glDisable(GL_LIGHTING);
			glDisable(GL_BLEND);
		}

		ERROR_CHECK;
		for (i = 0; i < polygons.size(); i++)
		{
			if (!Wireframe)
			{	
				tex_id = tc.TextureTranslate(polygons[i].texture_id, TC_TEXTURE);
				glow_tex_id = tc.TextureTranslate(polygons[i].texture_id, TC_GLOW);
				if (tex_id != -1 && !Textureless)
				{
					glActiveTexture(GL_TEXTURE0);
					glEnable(GL_TEXTURE_2D);
					glBindTexture(GL_TEXTURE_2D, tex_id);
											glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
						glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE);
						glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, GL_PRIMARY_COLOR);
						glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
						glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_TEXTURE);
						glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
						glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE, 1.0f);
					if(glow_tex_id > -1 && GLEE_ARB_multitexture){
												glActiveTexture(GL_TEXTURE1);
						glEnable(GL_TEXTURE_2D);
						glBindTexture(GL_TEXTURE_2D, glow_tex_id);
						glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
						glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_ADD);
						glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
						glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
						glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, GL_TEXTURE);
						glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
						glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE, 1.0f);
					}else{
												glActiveTexture(GL_TEXTURE1);
						glDisable(GL_TEXTURE_2D);
						glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
						glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
						glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
					}
				}
				else{
					glActiveTexture(GL_TEXTURE0);
					glDisable(GL_TEXTURE_2D);
					if(GLEE_ARB_multitexture){
						glActiveTexture(GL_TEXTURE1);
						glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
						glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
						glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
						glDisable(GL_TEXTURE_2D);
					}
				}
				glBegin(GL_POLYGON);
			}
			else
			{
				glBegin(GL_LINE_STRIP);
			}

			glNormal3fv((GLfloat *) &polygons[i].norm);
			for (unsigned int j = 0; j < polygons[i].verts.size(); j++)
			{
				if (!Wireframe && tex_id != -1 && !Textureless)
				{
					glMultiTexCoord2f(GL_TEXTURE0, polygons[i].verts[j].u, polygons[i].verts[j].v);
					glMultiTexCoord2f(GL_TEXTURE1, polygons[i].verts[j].u, polygons[i].verts[j].v);
				}		
				glNormal3fv((GLfloat *) &polygons[i].verts[j].norm);
				glVertex3fv((GLfloat *) &polygons[i].verts[j].point);
			}

			if (Wireframe)
			{
								glVertex3fv((GLfloat *) &polygons[i].verts[0].point);
			}

			glEnd();
		}

		if(glow_tex_id > -1 && GLEE_ARB_multitexture){
			glActiveTexture(GL_TEXTURE1);
			glDisable(GL_TEXTURE_2D);
			glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
		}

			ERROR_CHECK;

		if(!Wireframe && !Textureless){
			glDisable(GL_ALPHA_TEST);
			glEnable(GL_BLEND);
			glBlendFunc(GL_ONE,GL_ONE);
			glDepthMask(GL_FALSE);

			glActiveTexture(GL_TEXTURE0);

			glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE, light_zero );
			glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR, light_one );
			glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 65.0f );

			glEnable(GL_TEXTURE_2D);
					glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
			glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, GL_TEXTURE);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PRIMARY_COLOR);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
			glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE, 4.0f);


			for(i = 0; i < polygons.size(); i++)
			{
				shine_tex_id = tc.TextureTranslate(polygons[i].texture_id, TC_SHINEMAP);
				if(shine_tex_id >-1){
					glBindTexture(GL_TEXTURE_2D, shine_tex_id);
					glBegin(GL_POLYGON);
					glNormal3fv((GLfloat *) &polygons[i].norm);
					for (unsigned int j = 0; j < polygons[i].verts.size(); j++)
					{
						if (!Wireframe && tex_id != -1 && !Textureless)
						{
							glMultiTexCoord2f(GL_TEXTURE0, polygons[i].verts[j].u, polygons[i].verts[j].v);
						}		
						glNormal3fv((GLfloat *) &polygons[i].verts[j].norm);
						glVertex3fv((GLfloat *) &polygons[i].verts[j].point);
					}
					glEnd();
				}
			}
			glDisable(GL_BLEND);
			glDepthMask(GL_TRUE);
		}

			ERROR_CHECK;

		glDisable(GL_LIGHTING);
		glDisable(GL_TEXTURE_2D);

		glColor4ubv( (GLubyte*) get_SOBJ_color().col);

				if(highlight_active_model && sobj == active_submodel){
			OpenGL_RenderBox(subobjects[sobj].bounding_box_min_point_overridden ? subobjects[sobj].bounding_box_min_point_override : subobjects[sobj].bounding_box_min_point,
				subobjects[sobj].bounding_box_max_point_overridden ? subobjects[sobj].bounding_box_max_point_override : subobjects[sobj].bounding_box_max_point);
			for (i = 0; i < polygons.size(); i++)
			{

				glBegin(GL_LINE_STRIP);

				for (unsigned int j = 0; j < polygons[i].verts.size(); j++)
				{
					glVertex3fv((GLfloat *) &polygons[i].verts[j].point);
				}

								glVertex3fv((GLfloat *) &polygons[i].verts[0].point);

				glEnd();
			}
		}

		glColor4ubv( (GLubyte*) get_TXTR_color().col);
				if(active_texture >-1)
		for (i = 0; i < polygons.size(); i++)
		{
			if(polygons[i].texture_id == active_texture){
				glBegin(GL_LINE_STRIP);

				for (unsigned int j = 0; j < polygons[i].verts.size(); j++)
				{
					glVertex3fv((GLfloat *) &polygons[i].verts[j].point);
				}

								glVertex3fv((GLfloat *) &polygons[i].verts[0].point);

				glEnd();
			}
		}
	}
	

		if (draw_bsp && can_bsp_cache && bsp_cache[sobj].bsp_data.size() != 0)
	{
				
		RenderBSP(0, (unsigned char*)&bsp_cache[sobj].bsp_data.front(), subobjects[sobj].geometric_center);
	}

		glTranslatef(-trans.x, -trans.y, -trans.z);
	glActiveTexture(GL_TEXTURE0);

}

void PCS_Model::RenderGeometry_vertex_buffers(int sobj, TextureControl &tc){
		float light_one[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
	float light_zero[4] = { 0.0f, 0.0f, 0.0f, 1.0f };

		int tex_id = -1, glow_tex_id = -1, shine_tex_id = -1;
	glColor4f(1.0, 1.0, 1.0, 1.0); 
		glEnable(GL_LIGHTING);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_ALPHA_TEST);
		glAlphaFunc(GL_GREATER, 0.01f);

	ERROR_CHECK;
	if(!Wireframe)
	for(unsigned int t = 0; t<textures.size() + 1; t++){
		if(subobjects[sobj].vertex_buffer.size() <1)
			continue;
		if(subobjects[sobj].vertex_buffer[t].n_verts <1)
			continue;

		tex_id = tc.TextureTranslate(t, TC_TEXTURE);
		if(tex_id == -1 && !tc.solid_render(t))
			continue;
		glow_tex_id = tc.TextureTranslate(t, TC_GLOW);
		shine_tex_id = tc.TextureTranslate(t, TC_SHINEMAP);

		glBindBuffer(GL_ARRAY_BUFFER, subobjects[sobj].vertex_buffer[t].buffer);
		glLockArraysEXT( 0, subobjects[sobj].vertex_buffer[t].n_verts);
	ERROR_CHECK;
	
		glClientActiveTextureARB(GL_TEXTURE0);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_VERTEX_ARRAY);
		glVertexPointer(3,GL_FLOAT, subobjects[sobj].vertex_buffer[t].vertex_size, (void*)NULL);
		glNormalPointer(GL_FLOAT, subobjects[sobj].vertex_buffer[t].vertex_size, (void*)((vector3d*)NULL + 1));
		glTexCoordPointer(2, GL_FLOAT, subobjects[sobj].vertex_buffer[t].vertex_size, (void*)((vector3d*)NULL + 2));

		glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE, light_one );
		glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR, light_zero );
		
		if (tex_id != -1 && !Textureless){

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, tex_id);
			glEnable(GL_TEXTURE_2D);
					glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
			glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, GL_PRIMARY_COLOR);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_TEXTURE);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
			glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE, 1.0f);
						if(glow_tex_id > -1 && GLEE_ARB_multitexture){
								glClientActiveTextureARB(GL_TEXTURE1);
				glEnableClientState(GL_TEXTURE_COORD_ARRAY);
				glTexCoordPointer(2, GL_FLOAT, subobjects[sobj].vertex_buffer[t].vertex_size, (void*)((vector3d*)NULL + 2));
				glActiveTexture(GL_TEXTURE1);
				glEnable(GL_TEXTURE_2D);
					
				glBindTexture(GL_TEXTURE_2D, glow_tex_id);
				glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
				glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_ADD);
				glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
				glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
				glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, GL_TEXTURE);
				glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
				glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE, 1.0f);
			}else{
								glActiveTexture(GL_TEXTURE1);
				glDisable(GL_TEXTURE_2D);
				glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
				glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
				glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
			}
		}else{
			glActiveTexture(GL_TEXTURE0);
			glDisable(GL_TEXTURE_2D);
			if(GLEE_ARB_multitexture){
				glActiveTexture(GL_TEXTURE1);
				glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
				glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
				glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
				glDisable(GL_TEXTURE_2D);
			}
		}

	ERROR_CHECK;
		glDrawArrays(GL_TRIANGLES, 0, subobjects[sobj].vertex_buffer[t].n_verts);
		

		if(tex_id != -1 && !Textureless && glow_tex_id > -1 && GLEE_ARB_multitexture){
			glActiveTexture(GL_TEXTURE1);
			glDisable(GL_TEXTURE_2D);
			glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
		}

		if(tex_id != -1 && !Textureless && shine_tex_id >-1){
			glDisable(GL_ALPHA_TEST);
			glEnable(GL_BLEND);
			glBlendFunc(GL_ONE,GL_ONE);
			glDepthMask(GL_FALSE);

			glActiveTexture(GL_TEXTURE0);
			glEnable(GL_TEXTURE_2D);
			glBindTexture(GL_TEXTURE_2D, shine_tex_id);

			glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE, light_zero );
			glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR, light_one );
			glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 65.0f );

					glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);
			glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB, GL_TEXTURE);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB, GL_SRC_COLOR);
			glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PRIMARY_COLOR);
			glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
			glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE, 4.0f);


	ERROR_CHECK;
			glDrawArrays(GL_TRIANGLES, 0, subobjects[sobj].vertex_buffer[t].n_verts);

			glDisable(GL_BLEND);
			glDepthMask(GL_TRUE);
			glDisable(GL_TEXTURE_2D);
		}
		glUnlockArraysEXT();
	}
	ERROR_CHECK;

	glDisable(GL_LIGHTING);

	ERROR_CHECK;
	if((highlight_active_model && active_submodel == sobj) || Wireframe){
		if(!highlight_active_model || active_submodel != sobj)
			glColor3ub( (GLubyte)255, (GLubyte)255, (GLubyte)255);
		else
			glColor4ubv( (GLubyte*) get_SOBJ_color().col);
		if (highlight_active_model && active_submodel == sobj)
			OpenGL_RenderBox(subobjects[sobj].bounding_box_min_point_overridden ? subobjects[sobj].bounding_box_min_point_override : subobjects[sobj].bounding_box_min_point,
				subobjects[sobj].bounding_box_max_point_overridden ? subobjects[sobj].bounding_box_max_point_override : subobjects[sobj].bounding_box_max_point);
		for(unsigned int t = 0; t<textures.size() + 1; t++){
			if (subobjects[sobj].line_vertex_buffer[t].buffer != 0)
			{
				glBindBuffer(GL_ARRAY_BUFFER, subobjects[sobj].line_vertex_buffer[t].buffer);
				glLockArraysEXT( 0, subobjects[sobj].line_vertex_buffer[t].n_verts);

				glActiveTexture(GL_TEXTURE0);
				glClientActiveTextureARB(GL_TEXTURE0);
				glDisableClientState(GL_TEXTURE_COORD_ARRAY);
				glDisableClientState(GL_NORMAL_ARRAY);
				glEnableClientState(GL_VERTEX_ARRAY);
				glVertexPointer(3,GL_FLOAT, subobjects[sobj].line_vertex_buffer[t].vertex_size, (void*)NULL);

				glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE, light_one );
				glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR, light_zero );
				
				glDisable(GL_TEXTURE_2D);
				glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
				glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
				glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
			ERROR_CHECK;
				glDrawArrays(GL_LINES, 0, subobjects[sobj].line_vertex_buffer[t].n_verts);
				glUnlockArraysEXT();
			}
		}
	}

	ERROR_CHECK;
	if(active_texture >-1 && subobjects[sobj].line_vertex_buffer[active_texture].buffer != 0){
		glColor4ubv( (GLubyte*) get_TXTR_color().col);
		glBindBuffer(GL_ARRAY_BUFFER, subobjects[sobj].line_vertex_buffer[active_texture].buffer);
		glLockArraysEXT( 0, subobjects[sobj].line_vertex_buffer[active_texture].n_verts);
	ERROR_CHECK;
		glActiveTexture(GL_TEXTURE0);
		glClientActiveTextureARB(GL_TEXTURE0);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		glDisableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_VERTEX_ARRAY);
		glVertexPointer(3,GL_FLOAT, subobjects[sobj].line_vertex_buffer[active_texture].vertex_size, (void*)NULL);
	ERROR_CHECK;
		glMaterialfv( GL_FRONT_AND_BACK, GL_DIFFUSE, light_one );
		glMaterialfv( GL_FRONT_AND_BACK, GL_SPECULAR, light_zero );
	ERROR_CHECK;
		glDisable(GL_TEXTURE_2D);
		glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_REPLACE);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB, GL_PREVIOUS);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB, GL_SRC_COLOR);
	ERROR_CHECK;
		glDrawArrays(GL_LINES, 0, subobjects[sobj].line_vertex_buffer[active_texture].n_verts);
		glUnlockArraysEXT();
	}

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisableClientState(GL_NORMAL_ARRAY);
	ERROR_CHECK;
}


vector3d PCS_Model::OffsetFromParent(int ObjNum)
{
	vector3d RetVal = MakeVector(0, 0, 0);
	int parnum;

	parnum = subobjects[ObjNum].parent_sobj;
	if (parnum == -1)
		return RetVal;
	else
	{
		RetVal = subobjects[ObjNum].offset;
		return RetVal + OffsetFromParent(parnum);
	}
}


int PCS_Model::FindTexture(std::string name)
{
	for (unsigned int i = 0; i < textures.size(); i++)
		if (textures[i] == name)
			return i;
	return -1;
}

bobboau::matrix PCS_Model::moi_recalculate(int Xres, int Zres){
	float xw = (header.max_bounding.x - header.min_bounding.x)/(Xres);
	float zw = (header.max_bounding.z - header.min_bounding.z)/(Zres);

	bobboau::matrix ret = bobboau::matrix(vector3d(), vector3d(), vector3d());

	for(int x = 0; x<Xres; x++){
		for(int z = 0; z<Zres; z++){
			ret = ret + (moi_recalculate(header.min_bounding.x + x*xw + xw/2.0f, header.min_bounding.z + z*zw + zw/2.0f, xw, zw));
		}
	}

/*
	ret = moi_recalculate((header.max_bounding.x + header.min_bounding.x)/2
		,(header.max_bounding.z + header.min_bounding.z)/2
		,(header.max_bounding.x - header.min_bounding.x)
		,(header.max_bounding.z - header.min_bounding.z)
		,header.min_bounding.y,header.max_bounding.y-header.min_bounding.y);
	*/	
	ret = ret * header.mass;
	return ret.invert();
}

bobboau::matrix PCS_Model::moi_recalculate(float X, float Z, float xw, float zw){
	std::vector<vector3d> cpoints;
	if(!moi_colide(cpoints, X, Z))
		return bobboau::matrix(vector3d(), vector3d(), vector3d());		bobboau::matrix ret = moi_recalculate(X,Z,xw,zw,cpoints[0].y,cpoints[1].y-cpoints[0].y);
	for(unsigned int i = 1; i<cpoints.size()/2; i++){
		ret = ret + moi_recalculate(X,Z,xw,zw,cpoints[i].y,cpoints[i+1].y-cpoints[i].y);
	}
	return ret;
}

bobboau::matrix PCS_Model::moi_recalculate(float X, float Z, float xw, float zw, float Y, float dy){
	bobboau::matrix ret;
	double m = 1.0;	double ftm = 4.0/3.0*m;
	double X2 = X*X;
	double Y2 = Y*Y;
	double Z2 = Z*Z;
	double xw2 = xw*xw;
	double zw2 = zw*zw;
	double dy2 = dy*dy;
	ret.a2d[0][0] = ftm*(3.0*dy*Y + dy2 + zw2 + 3.0*Y2 + 12.0*Z2);
	ret.a2d[1][1] = ftm*(xw2 + zw2 + 12.0*X2 + 12.0*Z2);
	ret.a2d[2][2] = ftm*(3.0*dy*Y + dy2 + xw2 + 12.0*X2 + 3.0*Y2);

	ret.a2d[0][1] = ret.a2d[1][0] = -4.0*m*X*(dy+2.0*Y);
	ret.a2d[0][2] = ret.a2d[2][0] = -16.0*m*X*Z;
	ret.a2d[2][1] = ret.a2d[1][2] = -4.0*m*Z*(dy+2.0*Y);

	return ret;
}

vector3d poly_min(pcs_polygon&poly){
	vector3d ret;
	ret = poly.verts[0].point;
	for(unsigned int i = 1; i<poly.verts.size(); i++){
		vector3d&point = poly.verts[i].point;
		if(point.x < ret.x)ret.x = point.x;
		if(point.y < ret.y)ret.y = point.y;
		if(point.z < ret.z)ret.z = point.z;
	}
	return ret;
}

vector3d poly_max(pcs_polygon&poly){
	vector3d ret;
	ret = poly.verts[0].point;
	for(unsigned int i = 1; i<poly.verts.size(); i++){
		vector3d&point = poly.verts[i].point;
		if(point.x > ret.x)ret.x = point.x;
		if(point.y > ret.y)ret.y = point.y;
		if(point.z > ret.z)ret.z = point.z;
	}
	return ret;
}

int moicpcf(const void*a, const void*b){
	return ((vector3d*)(a))->y < ((vector3d*)(b))->y;
}

int point_face(vector3d *checkp, std::vector<pcs_vertex> verts, vector3d * norm1){
	std::vector<vector3d> v(verts.size());
	for(unsigned int i = 0; i< verts.size(); i++){
		v[i] = verts[i].point;
	}
	return point_face(checkp, v, norm1);
}

bool PCS_Model::moi_colide(std::vector<vector3d>&cpoints, float x, float z){
	pcs_sobj&model = subobjects[header.detail_levels[0]];
	for(unsigned int i = 0; i<model.polygons.size(); i++){
		pcs_polygon&poly = model.polygons[i];
		vector3d min = poly_min(poly);
		vector3d max = poly_max(poly);
		if(x>max.x || x<min.x)continue;
		if(z>max.z || z<min.z)continue;

		bool sucsess;
		vector3d cpoint = plane_line_intersect(poly.verts[0].point, poly.norm, vector3d(x,0.0f,z), vector3d(0.0f,1.0f,0.0f), &sucsess);
		if(!sucsess)continue;

		if(!point_face(&cpoint, poly.verts, &poly.norm))
			continue;

		cpoints.push_back(cpoint);
	}

	if(cpoints.size()%2)
		cpoints.resize(0);

	if(cpoints.size() > 0){
		qsort(&cpoints[0], cpoints.size(), sizeof(vector3d), moicpcf);
		return true;
	}else{
		return false;
	}
}

void PCS_Model::Transform(const matrix& transform, const vector3d& translation) {
	std::set<int> dock_paths;
	header.min_bounding = vector3d(FLT_MAX, FLT_MAX, FLT_MAX);
	header.max_bounding = vector3d(FLT_MIN, FLT_MIN, FLT_MIN);
	header.max_radius = 0.0f;
	for (std::vector<pcs_sobj>::iterator it = subobjects.begin(); it < subobjects.end(); ++it) {
		if (it->parent_sobj == -1) {
			it->Transform(*this, (int)(it - subobjects.begin()), transform, translation, true, true);
		}
	}
	if (header.max_radius == 0.0f) {
		header.min_bounding = vector3d(0.0f, 0.0f, 0.0f);
		header.max_bounding = vector3d(0.0f, 0.0f, 0.0f);
	}
	for (std::vector<pcs_special>::iterator it = special.begin(); it < special.end(); ++it) {
		it->Transform(*this, transform, translation);
	}
	for (std::vector<pcs_slot>::iterator it = weapons.begin(); it < weapons.end(); ++it) {
		it->Transform(transform, translation);
	}
	for (std::vector<pcs_dock_point>::iterator it = docking.begin(); it < docking.end(); ++it) {
		it->Transform(*this, transform, translation);
		for (std::vector<int>::iterator jt = it->paths.begin(); jt < it->paths.end(); ++jt) {
			dock_paths.insert(*jt);
		}
	}
	for (std::vector<pcs_thruster>::iterator it = thrusters.begin(); it < thrusters.end(); ++it) {
		it->Transform(transform, translation);
	}
	for (std::vector<pcs_shield_triangle>::iterator it = shield_mesh.begin(); it < shield_mesh.end(); ++it) {
		it->Transform(*this, transform, translation);
	}
	for (std::vector<pcs_insig>::iterator it = insignia.begin(); it < insignia.end(); ++it) {
		it->Transform(transform, translation);
	}
	for (std::vector<pcs_path>::iterator it = ai_paths.begin(); it < ai_paths.end(); ++it) {
		if (it->parent.empty() && dock_paths.find((int)(it - ai_paths.begin())) != dock_paths.end()) {
			it->Transform(transform, translation);
		}
	}
	header.mass_center = transform * header.mass_center + translation;
	header.mass *= std::fabs(transform.determinant());
	header.max_radius_override *= std::fabs(transform.determinant());
	header.min_bounding_override = transform * header.min_bounding_override + translation;
	header.max_bounding_override = transform * header.max_bounding_override + translation;
}

```

## pcs_file.h

```cpp


#if !defined(_pcs_file_h_)
#define _pcs_file_h_

#include <wx/msgdlg.h>
#include <wx/longlong.h>

#include "vector3d.h"
#include "POFHandler.h"

#include "pcs_file_dstructs.h"
#include <string>
#include <vector>
#include "tex_ctrl.h"
#include <cmath>
#include "AsyncProgress.h"

#define ERROR_CHECK {GLenum err = glGetError();\
	if(err != GL_NO_ERROR){\
		wxString fileline(wxString::Format(_("%s (%d)"), _(__FILE__), __LINE__));\
		wxMessageBox(wxString(_("Warning OGL reported \"")) +\
				wxString(reinterpret_cast<const char*>(gluErrorString(err)), wxConvUTF8) +\
			   	_("\" at ") + fileline + _("\n please report this issue"), _("OpenGL Error"));\
	}\
}


class TextureControl;
class model_editor_ctrl_base;
struct omnipoints;

#define PMF_VERSION 103
#define PMF_MIN_VERSION 100
#define PMF_MAX_VERSION PMF_VERSION

enum CHUNK { ROOT, HDR2, HDR2_SUB_DTL, HDR2_SUB_DEBRIS, ACEN, TXTR, SOBJ, PINF, EYE,
			SPCL, WEAP, GPNT, MPNT, WEAP_SUB, TGUN, TGUN_SUB, 
			DOCK, FUEL, FUEL_SUB, SHLD, INSG, INSG_SUB,
			PATH, PATH_SUB, GLOW, GLOW_SUB };

class PCS_Model 
{
	private:
		
												
		header_data header;

		vector3d autocentering; 
				std::vector<std::string> textures; 		std::vector<pcs_sobj> subobjects; 		std::vector<std::string> model_info; 		std::vector<pcs_eye_pos> eyes; 		std::vector<pcs_special> special; 		std::vector<pcs_slot> weapons; 		std::vector<pcs_turret> turrets; 		std::vector<pcs_dock_point> docking; 		std::vector<pcs_thruster> thrusters; 		std::vector<pcs_shield_triangle> shield_mesh; 		std::vector<pcs_insig> insignia; 		std::vector<pcs_path> ai_paths; 		std::vector<pcs_glow_array> light_arrays; 										std::vector<pmf_bsp_cache> bsp_cache;
		bool can_bsp_cache;

		bool has_fullsmoothing_data;

						
								int active_submodel;
		int active_texture;
		bool Wireframe;
		bool Textureless;
		bool highlight_active_model;
		bool vbos_enabled;




				void RenderGeometryRecursive(int sobj, TextureControl &tc, bool use_vbos);
		void RenderGeometry_vertex_buffers(int sobj, TextureControl &tc);
		int FindTexture(std::string name);


		bool PMFObj_to_POFObj2(int src_num, OBJ2 &dst, bool &bsp_compiled, float& model_radius);

		inline void POFTranslateBoundingBoxes(vector3d& min, vector3d& max) {
			float temp = -min.x;
			min.x = -max.x;
			max.x = temp;
		}

		bobboau::matrix moi_recalculate(float X, float Z, float xw, float zw);
		bobboau::matrix moi_recalculate(float X, float Z, float xw, float zw, float Y, float dy);
		bool moi_colide(std::vector<vector3d>&cpoints, float x, float z);

	public:
		bobboau::matrix moi_recalculate(int Xres, int Yres);
		vector3d OffsetFromParent(int ObjNum);
		void Transform(const matrix& transform, const vector3d& translation);

		PCS_Model() : header(), can_bsp_cache(false), has_fullsmoothing_data(false), active_submodel(0), Wireframe(false), Textureless(false), vbos_enabled(false), draw_bsp(false)
		{

		}
		~PCS_Model(){
			for(unsigned int i = 0; i<subobjects.size(); i++){
				subobjects[i].destroy_vertex_buffer();
			}
		}

				void Rcall_Wireframe(bool tf) { Wireframe = tf; }
		void Rcall_Textureless(bool tf) { Textureless = tf; }

		bool draw_bsp;
		
				static wxLongLong BSP_TREE_TIME;
		static unsigned int BSP_MAX_DEPTH;
		static unsigned int BSP_CUR_DEPTH;
		static unsigned int BSP_NODE_POLYS;
		static bool BSP_COMPILE_ERROR;


		void Reset();
		void PurgeBSPcache() { bsp_cache.resize(0); can_bsp_cache = false; }
				int LoadFromPMF(std::string filename, AsyncProgress* progress); 		int LoadFromPOF(std::string filename, AsyncProgress* progress);

		int LoadFromCOB(std::string filename, AsyncProgress* progress, float scaler, bool useFilter);
		int LoadFromDAE(std::string filename, AsyncProgress* progress, bool mirror_x, bool mirror_y, bool mirror_z);


		
				static bool split_poly(std::vector<pcs_polygon>&polys, int I, int i, int j);

		
						static void filter_polygon(std::vector<pcs_polygon>&polys, int i);

				static void filter_geometry(std::vector<pcs_polygon>&polys);


				void Calculate_Smoothing_Data(int &sobjs_comp); 
				int SaveToPMF(std::string filename, AsyncProgress* progress); 		int SaveToPOF(std::string filename, AsyncProgress* progress);

		int SaveToCOB(std::string filename, AsyncProgress* progress, float scaler);

										int SaveToDAE(std::string filename, AsyncProgress* progres, int helpers, int props_as_helpers);


				void Render(TextureControl &tc, bool use_vbos, bool highlight = false);
		void draw_shields();
		void draw_insignia(int lod, const omnipoints& omni);


				const header_data&get_header(){return header;}
		void set_header(const header_data&h){header = h;}
		float GetMaxRadius();
		float GetMass();
		void GetMOI(std::vector<float>& tensor);

		vector3d GetMinBounding();
		vector3d GetMaxBounding();
		vector3d GetCenterOfMass();
		vector3d GetAutoCenter();


		size_t GetModelInfoCount() { return model_info.size(); }
		int GetLODCount();
		int GetDebrisCount();
		int GetCrossSectCount();
		int GetTexturesCount();
		int GetSOBJCount();
		int GetEyeCount();
		int GetSpecialCount();
		int GetWeaponCount();
		int GetTurretCount();
		int GetDockingCount();
		int GetThrusterCount();
		int GetShldTriCount();
		int GetInsigniaCount();
		int GetPathCount();
		int GetLightCount();

		
		int&					LOD			(unsigned int idx);
		int&					Debris		(unsigned int idx);
		pcs_crs_sect&			CrossSect	(unsigned int idx);
		std::string&				Texture		(unsigned int idx);
		pcs_sobj&				SOBJ		(unsigned int idx);
		pcs_eye_pos&			Eye			(unsigned int idx);
		pcs_special&			Special		(unsigned int idx);
		pcs_slot&				Weapon		(unsigned int idx);
		pcs_turret&				Turret		(unsigned int idx);
		pcs_dock_point&			Dock		(unsigned int idx);
		pcs_thruster&			Thruster	(unsigned int idx);
		pcs_shield_triangle&	ShldTri		(unsigned int idx);
		pcs_insig&				Insignia	(unsigned int idx);
		pcs_path&				Path		(unsigned int idx);
		pcs_glow_array&			Light		(unsigned int idx);
		std::string&				ModelInfo	(unsigned int idx);

				void SetMaxRadius(float rad);
		void SetMass(float mass);
		void SetMOI(float tensor[3][3]); 
		void SetMinBounding(const vector3d &bnd);
		void SetMaxBounding(const vector3d &bnd);
		void SetCenterOfMass(const vector3d &cnt);
		void SetAutoCenter(const vector3d &cnt);

		void AddModelInfo(std::string info="");
		void SetModelInfo(unsigned int idx, std::string info);

		void SetNumLODs(int num) { header.detail_levels.resize(num); }
		void AddLOD(int sobj=-1); 		void DelLOD(unsigned int idx);

		void SetNumDebris(int num) { header.debris_pieces.resize(num); }
		void AddDebris(int sobj=-1); 		void DelDebris(unsigned int idx);

		void SetNumCrossSects(int num) { header.cross_sections.resize(num); }
		void AddCrossSect(pcs_crs_sect *cs=NULL); 		void DelCrossSect(unsigned int idx);

		int maybeAddTexture(std::string txt);
		void AddTextures(std::string txt="");
		void DelTextures(unsigned int idx);

		void AddSOBJ(pcs_sobj *obj=NULL);
		void DelSOBJ(int idx);
		void SetObjectChanged(unsigned int idx);

		void AddEye(pcs_eye_pos *eye=NULL);
		void DelEye(unsigned int idx);

		void AddSpecial(pcs_special *spcl=NULL);
		void DelSpecial(unsigned int idx);

		void AddWeapon(pcs_slot *weap=NULL);
		void DelWeapon(unsigned int idx);

		void AddTurret(pcs_turret *trrt=NULL);
		void DelTurret(unsigned int idx);

		void AddDocking(pcs_dock_point *dock=NULL);
		void DelDocking(unsigned int idx);

		void AddThruster(pcs_thruster *thrust=NULL);
		void DelThruster(unsigned int idx);

		void AddShldTri(pcs_shield_triangle *stri=NULL);
		void DelShldTri(unsigned int idx);

		void AddInsignia(pcs_insig *insig=NULL);
		void DelInsignia(unsigned int idx);

		void AddPath(pcs_path *path=NULL);
		void DelPath(unsigned int idx);

		void AddLight(pcs_glow_array *lights=NULL);
		void DelLight(unsigned int idx);

					std::vector<std::string> get_textures(){return textures;}
			void set_textures(const std::vector<std::string> &t){
				if (t.size() != textures.size()) {
					textures = t;
					make_vertex_buffers();
				} else {
					textures = t;
				}
			}

			std::vector<pcs_sobj> get_subobjects(){return subobjects;}
			void set_subobjects(const std::vector<pcs_sobj> &t){subobjects = t;}

			std::vector<std::string> get_model_info(){return model_info;}
			void set_model_info(const std::vector<std::string> &t){model_info = t;}
	
			std::vector<pcs_eye_pos> get_eyes(){return eyes;}
			void set_eyes(const std::vector<pcs_eye_pos> &t){eyes = t;}
	
			std::vector<pcs_special> get_special(){return special;}
			void set_special(const std::vector<pcs_special> &t){special = t;}
		
			std::vector<pcs_slot> get_weapons(){return weapons;}
			void set_weapons(const std::vector<pcs_slot> &t){weapons = t;}
		
			std::vector<pcs_turret> get_turrets(){return turrets;}
			void set_turrets(const std::vector<pcs_turret> &t){turrets = t;}
		
			std::vector<pcs_dock_point> get_docking(){return docking;}
			void set_docking(const std::vector<pcs_dock_point> &t){docking = t;}
		
			std::vector<pcs_thruster> get_thrusters(){return thrusters;}
			void set_thrusters(const std::vector<pcs_thruster> &t){thrusters = t;}
		
			std::vector<pcs_shield_triangle> get_shield_mesh(){return shield_mesh;}
			void set_shield_mesh(const std::vector<pcs_shield_triangle> &t){shield_mesh = t;}
		
			std::vector<pcs_insig> get_insignia(){return insignia;}
			void set_insignia(const std::vector<pcs_insig> &t){insignia = t;}
		
			std::vector<pcs_path> get_ai_paths(){return ai_paths;}
			void set_ai_paths(const std::vector<pcs_path> &t){ai_paths = t;}
	
			std::vector<pcs_glow_array> get_glow_points(){return light_arrays;}
			void set_glow_points(const std::vector<pcs_glow_array> &t){light_arrays = t;}

			void set_active_model(int idx){active_submodel = idx;}
			int get_active_model(){return active_submodel;};

			void set_active_texture(int idx){active_texture = idx;}
			int get_active_texture(){return active_texture;};

			int find_LOD_root(int idx){
				if(idx<0)
					return 0;
				if(subobjects[idx].parent_sobj <0)
					return idx;
				for(unsigned int i = 0; i<header.detail_levels.size(); i++){
					if(idx == header.detail_levels[i])
						return idx;
				}
				return find_LOD_root(subobjects[idx].parent_sobj);
			}

			bool is_debris(int idx){
				if(idx<0)
					return false;
				for(unsigned int i = 0; i<header.debris_pieces.size(); i++){
					if(idx == header.debris_pieces[i])
						return true;
				}
				return false;
			}

			vector3d get_model_offset(int i){
				if(i>=(int)subobjects.size())
					return vector3d(0,0,0);
				if(i <0)
					return autocentering;
				return get_model_offset(subobjects[i].parent_sobj) + subobjects[i].offset; 
			}

						size_t get_child_subobj_poly_count(int idx){
			size_t total = 0;
								for(unsigned int i = 0; i<subobjects.size(); i++){
					if(subobjects[i].parent_sobj == idx){
						total += subobjects[i].polygons.size() + get_child_subobj_poly_count(i);
					}
				}
				return total;
			}


			bool get_bsp_cache_status(){return can_bsp_cache;}

						float get_avg_dimintion(){
				float d[6];
				d[0] = std::fabs(header.min_bounding.x);
				d[1] = std::fabs(header.min_bounding.y);
				d[2] = std::fabs(header.min_bounding.z);
				d[3] = std::fabs(header.max_bounding.x);
				d[4] = std::fabs(header.max_bounding.y);
				d[5] = std::fabs(header.max_bounding.z);

				float avg = 0;
				for(int i = 0; i<6; i++){
					avg += d[i];
				}
				avg/=6.0f;
				return avg;
			}

	void init_vertex_buffers(bool enabled);	void make_vertex_buffers();	void make_vertex_buffer(int sobj);
};


#endif 

```

## pcs_file_dstructs.cpp

```cpp


#include <cfloat>
#include <set>
#include <boost/algorithm/string.hpp>

#include "pcs_file.h"
#include "pcs_file_dstructs.h"
#include "matrix3d.h"



void BF_ReadString(std::istream &in, std::string &retval)
{
	int len;

	in.read((char *)&len, sizeof(int));

	char *str = new char[len+1];
	in.read(str,len);
	str[len] = '\0';
	
	retval = str;
	delete[] str;


}


void BF_WriteString(std::ostream &out, std::string &str)
{
	int len = str.length();

	out.write((char *)&len, sizeof(int));
	out.write(str.c_str(), len);
}

void pcs_vertex::Read(std::istream& in, int ver)
{
	BFRead(point, vector3d)
	BFRead(norm, vector3d)
	BFRead(u, float)
	BFRead(v, float)
	if (ver >= 101) {
		BFRead(facet_angle, float)
	} else { facet_angle = -1; }
}

void pcs_vertex::Write(std::ostream& out)
{
	BFWrite(point, vector3d)
	BFWrite(norm, vector3d)
	BFWrite(u, float)
	BFWrite(v, float)
	BFWrite(facet_angle, float)
}

void pcs_polygon::Read(std::istream& in, int ver)
{

	if (ver >= 101)
		BFReadAdvVector(verts)
	else
		BFReadVector(verts)
	BFRead(texture_id, int)
	BFRead(norm, vector3d)
}

void pcs_polygon::Write(std::ostream& out)
{

	BFWriteAdvVector(verts)
	BFWrite(texture_id, int)
	BFWrite(norm, vector3d)

}


void pcs_sobj::Write(std::ostream& out)
{
		BFWrite(parent_sobj, int)
	BFWrite(radius_overridden ? radius_override : radius, float)
	BFWrite(offset, vector3d)
	BFWrite(geometric_center, vector3d)
	BFWrite(bounding_box_min_point_overridden ? bounding_box_min_point_override : bounding_box_min_point, vector3d)
	BFWrite(bounding_box_max_point_overridden ? bounding_box_max_point_override : bounding_box_max_point, vector3d)
	BFWriteString(name);
	BFWriteString(properties);
	BFWrite(movement_type, int)
	BFWrite(movement_axis, int)

	int cnt = polygons.size();
	BFWrite(cnt, int)
	for (int i = 0; i < cnt; i++)
		polygons[i].Write(out);
}

void pcs_sobj::Read(std::istream &in, int ver)
{
	BFRead(parent_sobj, int)
	BFRead(radius, float)
	radius_override = radius;
	BFRead(offset, vector3d)
	BFRead(geometric_center, vector3d)
	BFRead(bounding_box_min_point, vector3d)
	bounding_box_min_point_override = bounding_box_min_point;
	BFRead(bounding_box_max_point, vector3d)
	bounding_box_max_point_override = bounding_box_max_point;
	BFReadString(name);
	BFReadString(properties);
	BFRead(movement_type, int)
	BFRead(movement_axis, int)

	int cnt;
	BFRead(cnt, int)
	polygons.resize(cnt);
	for (int i = 0; i < cnt; i++)
		polygons[i].Read(in, ver);
}


void pcs_special::Read(std::istream& in, int ver)
{
	BFReadString(name)
	BFReadString(properties)
	BFRead(point, vector3d)
	BFRead(radius, float)
}

void pcs_special::Write(std::ostream& out)
{
	BFWriteString(name)
	BFWriteString(properties)
	BFWrite(point, vector3d)
	BFWrite(radius, float)
}


void pcs_slot::Read(std::istream& in, int ver)
{
	BFRead(type, int)
	BFReadVector(muzzles)
}

void pcs_slot::Write(std::ostream& out)
{
	BFWrite(type, int)
	BFWriteVector(muzzles)
}


void pcs_turret::Read(std::istream& in, int ver)
{	
	BFRead(type, int)
	BFRead(sobj_parent, int)
	BFRead(sobj_par_phys, int)
	BFRead(turret_normal, vector3d)
	BFReadVector(fire_points)
}

void pcs_turret::Write(std::ostream& out)
{	
	BFWrite(type, int)
	BFWrite(sobj_parent, int)
	BFWrite(sobj_par_phys, int)
	BFWrite(turret_normal, vector3d)
	BFWriteVector(fire_points)
}


void pcs_dock_point::Read(std::istream& in, int ver)
{
	BFReadString(properties)
	BFReadVector(paths)
	BFReadVector(dockpoints)
}

void pcs_dock_point::Write(std::ostream& out)
{
	BFWriteString(properties)
	BFWriteVector(paths)
	BFWriteVector(dockpoints)
}


void pcs_thruster::Read(std::istream& in, int ver)
{
	BFReadVector(points)
	BFReadString(properties)
}

void pcs_thruster::Write(std::ostream& out)
{
	BFWriteVector(points)
	BFWriteString(properties)
}


void pcs_insig::Read(std::istream& in, int ver)
{
	BFRead(lod, int)
	BFRead(offset, vector3d)
	BFReadVector(faces)
}

void pcs_insig::Write(std::ostream& out)
{
	BFWrite(lod, int)
	BFWrite(offset, vector3d)
	BFWriteVector(faces)
}

bool pcs_insig::Generate(const std::vector<pcs_polygon>& polygons, const float epsilon)
{
	if (!(generator.up != vector3d() && generator.forward != vector3d() &&
				generator.radius > 0.0f && generator.subdivision > 0)) {
		return false;
	}
	vector3d forward = MakeUnitVector(generator.forward);
	vector3d up = MakeUnitVector(
			generator.up - (dot(generator.up, forward) * forward));
	vector3d right = CrossProduct(forward, up);
	matrix transform(up, right, forward);
	transform = transform * (2.0f / generator.radius);

	std::vector<std::vector<vector3d> > polys;
	for (std::vector<pcs_polygon>::const_iterator it = polygons.begin(); it != polygons.end(); ++it) {
		if (dot(it->norm, forward) >= 0) {
			continue;
		}
		std::vector<vector3d> transformed;
		for (std::vector<pcs_vertex>::const_iterator jt = it->verts.begin(); jt != it->verts.end(); ++jt) {
			transformed.push_back(transform * (jt->point - generator.pos));
		}
		if (!outside_viewport(transformed)) {
			polys.push_back(transformed);
		}
	}
	std::vector<float> zbuffer(generator.subdivision * generator.subdivision, FLT_MAX);
	std::vector<int> zbuffer_idx(generator.subdivision * generator.subdivision, -1);
	for (unsigned int j = 0; j < polys.size(); j++) {
		for (int i = 0; i < generator.subdivision; i++) {
			for (int k = 0; k < generator.subdivision; k++) {
				vector3d point(i * 2.0f / (generator.subdivision) - 1,
						k * 2.0f / (generator.subdivision) - 1, 0);
				if (inside_polygon(point, polys[j])) {
					float result = interpolate_z(point, polys[j]);
					if (result < zbuffer[i * generator.subdivision + k]) {
						zbuffer[i * generator.subdivision + k] = result;
						zbuffer_idx[i * generator.subdivision + k] = j;
					}
				}
			}
		}
	}
	std::set<unsigned int> included_polys;
	for (unsigned int i = 0; i < zbuffer_idx.size(); i++) {
		if (zbuffer_idx[i] != -1) {
			included_polys.insert(zbuffer_idx[i]);
		}
	}
	transform = transform.invert();
	pcs_insig_face face;
	vector3d min_bounding_box, max_bounding_box;
	bool merged = true;
	while (merged) {
		merged = false;
		for (std::set<unsigned int>::const_iterator it = included_polys.begin(); it != included_polys.end(); ++it) {
			std::set<unsigned int>::const_iterator jt = it;
		   	++jt;
			for (; jt != included_polys.end(); ++jt) {
				if (dot(MakeUnitVector(CrossProduct(polys[*it][1] - polys[*it][0],
									polys[*it][2] - polys[*it][0])),
							MakeUnitVector(CrossProduct(polys[*jt][1] - polys[*jt][0],
									polys[*jt][2] - polys[*jt][0]))) > epsilon) {
					for (size_t k = 0; k < polys[*it].size() && !merged; k++) {
						for (size_t l = 0; l < polys[*jt].size() && !merged; l++) {
							if (polys[*it][(k + 1) % polys[*it].size()] == polys[*jt][l] &&
									polys[*it][k] == polys[*jt][(l + 1) % polys[*jt].size()]) {
																merged = true;
								polys[*it].resize(polys[*it].size() + polys[*jt].size() - 2);
																for (size_t i = polys[*it].size() - 1; i > k + 1; i--) {
									polys[*it][i] = polys[*it][i - polys[*jt].size() + 2];
								}
																int i = k + 1;
								for (size_t j = (l + 2) % polys[*jt].size(); j != l; j = (j + 1) % polys[*jt].size()) {
									polys[*it][i] = polys[*jt][j];
									i++;
								}
								included_polys.erase(jt);
							}
						}
					}
				}
			}
		}
	}
	for (std::set<unsigned int>::const_iterator it = included_polys.begin(); it != included_polys.end(); ++it) {
		std::vector<vector3d> clipped_poly(clip(polys[*it]));
		for (unsigned int i = 0; i < clipped_poly.size() - 2; i++) {
			face.verts[0] = generator.pos + (transform * clipped_poly[i]);
			face.u[0] = (1.0f + clipped_poly[i].y) / 2.0f;
			face.v[0] = (1.0f -clipped_poly[i].x) / 2.0f;
			face.verts[1] = generator.pos + (transform * clipped_poly[i + 1]);
			face.u[1] = (1.0f + clipped_poly[i + 1].y) / 2.0f;
			face.v[1] = (1.0f -clipped_poly[i + 1].x) / 2.0f;
			face.verts[2] = generator.pos + (transform * clipped_poly[clipped_poly.size() - 1]);
			face.u[2] = (1.0f + clipped_poly[clipped_poly.size() - 1].y) / 2.0f;
			face.v[2] = (1.0f -clipped_poly[clipped_poly.size() - 1].x) / 2.0f;
			faces.push_back(face);
			for (int j = 0; j < 3; j++) {
				for (int k = 0; k < 3; k++) {
					if (face.verts[j][k] > max_bounding_box[k]) {
						max_bounding_box[k] = face.verts[j][k];
					}
					if (face.verts[j][k] < min_bounding_box[k]) {
						min_bounding_box[k] = face.verts[j][k];
					}
				}
			}
		}
	}
	vector3d center = min_bounding_box + ((max_bounding_box - min_bounding_box) / 2.0f);
	offset = center - forward * (generator.distance);
	for (unsigned int i = 0; i < faces.size(); i++) {
		for (int j = 0; j < 3; j++) {
			faces[i].verts[j] -= center;
		}
	}
	return true;
}

namespace {
	class edge {
		float a, b, c;
		public:
		edge(float a_in, float b_in, float c_in) : a(a_in), b(b_in), c(c_in) {}

		bool inside(const vector3d& v) const {
			return a * v.x + b*v.y + c >= 0;
		}

		vector3d intersection(const vector3d& u, const vector3d& v) const {
			vector3d direction = v - u;
			float t = (a * u.x + b*u.y + c) / (a * (u.x - v.x) + b * (u.y - v.y));
			return u + (t * direction);
		}
	};

	std::vector<vector3d> clip_edge(const std::vector<vector3d> verts, const edge& current_edge) {
		std::vector<vector3d> result;
		unsigned int i;
		int j;
		for (i = 0, j = verts.size() - 1; i < verts.size(); j = i++) {
			if (current_edge.inside(verts[i])) {
				if (!current_edge.inside(verts[j])) {
					result.push_back(current_edge.intersection(verts[i], verts[j]));
				}
				result.push_back(verts[i]);
			} else if (current_edge.inside(verts[j])) {
				result.push_back(current_edge.intersection(verts[i], verts[j]));
			}
		}
		return result;
	}

}

std::vector<vector3d> pcs_insig::clip(const std::vector<vector3d>& verts) {
	return clip_edge(clip_edge(clip_edge(clip_edge(verts, edge(1, 0, 1)), edge(-1, 0, 1)), edge(0, 1, 1)), edge(0, -1, 1));

}

float pcs_insig::interpolate_z(const vector3d& v, const std::vector<vector3d>& verts) {
	if (verts.size() < 3) {
		return FLT_MAX;
	}
	matrix transform(verts[0], verts[1], verts[2]);
	for (int i = 0; i < 3; i++) {
		transform.a2d[i][2] = 1.0f;
	}
	transform = transform.invert();
	vector3d z(verts[0].z, verts[1].z, verts[2].z);
	return dot(transform * z, vector3d(v.x, v.y, 1));
}

bool pcs_insig::inside_polygon(const vector3d& v, const std::vector<vector3d>& verts) {
	bool result = false;
	unsigned int i;
	int j;
	for (i = 0, j = verts.size() - 1; i < verts.size(); j = i++) {
		if ((verts[i].y > v.y) != (verts[j].y > v.y) &&
				(v.x < (verts[j].x-verts[i].x) * (v.y-verts[i].y) / (verts[j].y-verts[i].y) + verts[i].x)) {
			result = !result;
		}
	}
	return result;
}

bool pcs_insig::outside_viewport(const std::vector<vector3d>& verts) {
	bool abovex(true), abovey(true), belowx(true), belowy(true), belowz(true);
	for (std::vector<vector3d>::const_iterator it = verts.begin(); it != verts.end(); ++it) {
		if (it->x >= -1.0f) {
			belowx = false;
		}
		if (it->x <= 1.0f) {
			abovex = false;
		}
		if (it->y >= -1.0f) {
			belowy = false;
		}
		if (it->y <= 1.0f) {
			abovey = false;
		}
		if (it->z >= 0.0f) {
			belowz = false;
		}
	}
	return abovex || abovey || belowx || belowy || belowz;
}


void pcs_path::Read(std::istream& in, int ver)
{
	BFReadString(name)
	BFReadString(parent)
	BFReadVector(verts)
}

void pcs_path::Write(std::ostream& out)
{
	BFWriteString(name)
	BFWriteString(parent)
	BFWriteVector(verts)
}

  
void pcs_glow_array::Read(std::istream& in, int ver)
{
	BFRead(disp_time, int)
	BFRead(on_time, int)
	BFRead(off_time, int)
	BFRead(obj_parent, int)
	BFRead(LOD, int)
	BFRead(type, int)
	BFReadString(properties)
	BFReadVector(lights)
}

void pcs_glow_array::Write(std::ostream& out)
{
	BFWrite(disp_time, int)
	BFWrite(on_time, int)
	BFWrite(off_time, int)
	BFWrite(obj_parent, int)
	BFWrite(LOD, int)
	BFWrite(type, int)
	BFWriteString(properties)
	BFWriteVector(lights)
}



#include <cstdio>
void pmf_bsp_cache::Read(std::istream& in, int ver)
{
	if (ver >= 103) {
		BFReadVector(bsp_data)
		BFRead(changed, bool)
	}
	else if (ver >= 102)
	{
		int bsp_size;
		BFRead(bsp_size, int)
		if (bsp_size != 0) 
		{
			bsp_data.resize(bsp_size);
						BFRead(bsp_data.front(), bsp_size)
		}
		BFRead(changed, bool)
						bsp_data.clear();
		changed = true;
	}
}
	
void pmf_bsp_cache::Write(std::ostream& out)
{
		BFWriteVector(bsp_data)
	BFWrite(changed, bool)
}


void pcs_sobj::Transform(PCS_Model& model, int idx, const matrix& transform, const vector3d& translation, bool transform_pivot, bool fixed_pivot) {
	if (parent_sobj == -1) {
		fixed_pivot = true;
	}
	TransformBefore(model, idx);
	TransformAfter(model, idx, transform, translation, transform_pivot, fixed_pivot);
}

void pcs_sobj::TransformBefore(PCS_Model& model, int idx) {
	vector3d global_offset(-1.0f * model.OffsetFromParent(idx));
	matrix transform;
		for (int i = 0; i < model.GetSOBJCount(); i++) {
		pcs_sobj& other = model.SOBJ(i);
		if (other.parent_sobj == idx) {
			other.TransformBefore(model, i);
		}
	}
		for (int i = 0; i < model.GetPathCount(); i++) {
		pcs_path& path = model.Path(i);
		if (!path.parent.empty() &&
		    (boost::algorithm::iequals(path.parent, name) ||
		     (path.parent.size() > 1 && boost::algorithm::iequals(path.parent.substr(1), name)) ||
		     (name.size() > 1 && boost::algorithm::iequals(path.parent, name.substr(1))))) {
			path.Transform(transform, global_offset);
		}
	}
		for (int i = 0; i < model.GetLightCount(); i++) {
		pcs_glow_array& lights = model.Light(i);
		if (lights.obj_parent == idx) {
			lights.Transform(transform, global_offset);
		}
	}
}

void pcs_sobj::TransformAfter(PCS_Model& model, int idx, const matrix& transform, const vector3d& translation, bool transform_pivot, bool fixed_pivot) {
			vector3d subtranslation = translation;
	if (transform_pivot) {
		offset = transform * offset;
	}
	if (!fixed_pivot) {
		offset += subtranslation;
		subtranslation = vector3d();
	}
	vector3d global_offset(model.OffsetFromParent(idx));
	bool should_reverse = transform.determinant() < 0.0f;
	header_data header = model.get_header();

	if (!polygons.empty()) {
		bounding_box_min_point = vector3d(FLT_MAX, FLT_MAX, FLT_MAX);
		bounding_box_max_point = vector3d(FLT_MIN, FLT_MIN, FLT_MIN);
		radius = 0.0f;
	}
	for (std::vector<pcs_polygon>::iterator it = polygons.begin(); it < polygons.end(); ++it) {
		it->norm = SafeMakeUnitVector(transform * it->norm);
		it->centeroid = transform * it->centeroid + subtranslation;
		for (std::vector<pcs_vertex>::iterator jt = it->verts.begin(); jt < it->verts.end(); ++jt) {
			jt->point = transform * jt->point + subtranslation;
			ExpandBoundingBoxes(bounding_box_max_point, bounding_box_min_point, jt->point);
			float point_radius = Magnitude(jt->point);
			if (point_radius > radius) {
				radius = point_radius;
			}
						float point_global_radius = Magnitude(jt->point + global_offset);
			if (point_global_radius > header.max_radius) {
				header.max_radius = point_global_radius;
			}
			ExpandBoundingBoxes(header.max_bounding, header.min_bounding, jt->point + global_offset);
			jt->norm = SafeMakeUnitVector(transform * jt->norm);
		}
		if (should_reverse) {
			std::reverse(it->verts.begin(), it->verts.end());
		}
	}
	model.set_header(header);
		model.SOBJ(idx) = *this;
		for (int i = 0; i < model.GetSOBJCount(); i++) {
		pcs_sobj& other = model.SOBJ(i);
		if (other.parent_sobj == idx) {
			other.TransformAfter(model, i, transform, subtranslation, true, false);
		}
	}
		for (int i = 0; i < model.GetTurretCount(); i++) {
		pcs_turret& turret = model.Turret(i);
		if (turret.sobj_par_phys == idx) {
			turret.Transform(transform, subtranslation);
		}
	}
		for (int i = 0; i < model.GetEyeCount(); i++) {
		pcs_eye_pos& eye = model.Eye(i);
		if (eye.sobj_number == idx) {
			eye.Transform(transform, subtranslation);
		}
	}
		for (int i = 0; i < model.GetPathCount(); i++) {
		pcs_path& path = model.Path(i);
		if (!path.parent.empty() &&
		    (boost::algorithm::iequals(path.parent, name) ||
		     (path.parent.size() > 1 && boost::algorithm::iequals(path.parent.substr(1), name)) ||
		     (name.size() > 1 && boost::algorithm::iequals(path.parent, name.substr(1))))) {
			path.Transform(transform, subtranslation + global_offset);
		}
	}
		for (int i = 0; i < model.GetLightCount(); i++) {
		pcs_glow_array& lights = model.Light(i);
		if (lights.obj_parent == idx) {
			lights.Transform(transform, subtranslation + global_offset);
		}
	}
	model.SetObjectChanged(idx);
}

void pcs_turret::Transform(const matrix& transform, const vector3d& translation) {
	turret_normal = SafeMakeUnitVector(transform * turret_normal);
	for (std::vector<vector3d>::iterator it = fire_points.begin(); it < fire_points.end(); ++it) {
		*it = transform * *it + translation;
	}
}

void pcs_eye_pos::Transform(const matrix& transform, const vector3d& translation) {
	sobj_offset = transform * sobj_offset + translation;
	normal = SafeMakeUnitVector(transform * normal);
}

void pcs_glow_array::Transform(const matrix& transform, const vector3d& translation) {
	for (std::vector<pcs_thrust_glow>::iterator it = lights.begin(); it < lights.end(); ++it) {
		it->Transform(transform, translation);
	}
}

void pcs_thruster::Transform(const matrix& transform, const vector3d& translation) {
	for (std::vector<pcs_thrust_glow>::iterator it = points.begin(); it < points.end(); ++it) {
		it->Transform(transform, translation);
	}
}

void pcs_thrust_glow::Transform(const matrix& transform, const vector3d& translation) {
	float norm_before, norm_after;
	pos = transform * pos + translation;
	norm_before = Magnitude(norm);
	norm = transform * norm;
	norm_after = Magnitude(norm);
	norm = SafeMakeUnitVector(norm);
	if (norm_after > 1e-5) {
		radius *= sqrt(std::fabs(transform.determinant() / norm_after * norm_before));
	} else {
		radius *= pow(std::fabs(transform.determinant()), 1.0f / 3);
	}
}

void pcs_insig::Transform(const matrix& transform, const vector3d& translation) {
	offset = transform * offset + translation;
	for (std::vector<pcs_insig_face>::iterator it = faces.begin(); it < faces.end(); ++it) {
		it->Transform(transform, vector3d());
	}
	generator.Transform(transform, translation);
}

void pcs_insig_generator::Transform(const matrix& transform, const vector3d& translation) {
	pos = transform * pos + translation;
	forward = SafeMakeUnitVector(transform * forward);
	up = SafeMakeUnitVector(transform * up);
}

void pcs_insig_face::Transform(const matrix& transform, const vector3d& translation) {
	for(int i = 0; i < 3; i++) {
		verts[i] = transform * verts[i] + translation;
	}
	if (transform.determinant() < 0.0f) {
		std::reverse(verts, verts + 3);
	}
}

void pcs_path::Transform(const matrix& transform, const vector3d& translation) {
	for (std::vector<pcs_pvert>::iterator it = verts.begin(); it < verts.end(); ++it) {
		it->Transform(transform, translation);
	}
}

void pcs_pvert::Transform(const matrix& transform, const vector3d& translation) {
	pos = transform * pos + translation;
	radius *= pow(std::fabs(transform.determinant()), 1.0f / 3);
}

void pcs_dock_point::Transform(PCS_Model& model, const matrix& transform, const vector3d& translation) {
	for (std::vector<pcs_hardpoint>::iterator it = dockpoints.begin(); it < dockpoints.end(); ++it) {
		it->Transform(transform, translation);
	}
		for (std::vector<int>::iterator it = paths.begin(); it < paths.end(); ++it) {
			if (*it < model.GetPathCount() && *it >= 0) {
				model.Path(*it).Transform(transform, translation);
			}
		}
}

void pcs_shield_triangle::Transform(PCS_Model& model, const matrix& transform, const vector3d& translation) {
	face_normal = SafeMakeUnitVector(transform * face_normal);
	header_data header = model.get_header();
	for (int i = 0; i < 3; i++) {
		corners[i] = transform * corners[i] + translation;
		ExpandBoundingBoxes(header.max_bounding, header.min_bounding, corners[i]);
	}
	if (transform.determinant() < 0.0f) {
		std::reverse(corners, corners + 3);
	}
	model.set_header(header);
}

void pcs_hardpoint::Transform(const matrix& transform, const vector3d& translation) {
	norm = SafeMakeUnitVector(transform * norm);
	point = transform * point + translation;
}

void pcs_slot::Transform(const matrix& transform, const vector3d& translation) {
	for (std::vector<pcs_hardpoint>::iterator it = muzzles.begin(); it < muzzles.end(); ++it) {
		it->Transform(transform, translation);
	}
}

void pcs_special::Transform(PCS_Model& model, const matrix& transform, const vector3d& translation) {
	point = transform * point + translation;
	radius *= pow(std::fabs(transform.determinant()), 1.0f / 3);
	for (int i = 0; i < model.GetPathCount(); i++) {
		pcs_path& path = model.Path(i);
		if (!path.parent.empty() &&
		    (boost::algorithm::iequals(path.parent, name) ||
		     (path.parent.size() > 1 && boost::algorithm::iequals(path.parent.substr(1), name)) ||
		     (name.size() > 1 && boost::algorithm::iequals(path.parent, name.substr(1))))) {
			path.Transform(transform, translation);
		}
	}
}

```

## pcs_file_dstructs.h

```cpp


#if !defined(_pcs_file_dstructs_h_)
#define _pcs_file_dstructs_h_

#include "vector3d.h"
#include "matrix3d.h"
#include <string>
#include "ogl_vertex_buffers.h"


#include <iostream>


#define BFWrite(obj, type) out.write((char *)&(obj), sizeof(type));
#define BFRead(obj, type) in.read((char *)&(obj), sizeof(type));
#define BFWriteString(string) BF_WriteString(out, string);
#define BFReadString(string) BF_ReadString(in, string);
#define BFWriteVector(vector) BF_WriteVector(out, vector);
#define BFReadVector(vector) BF_ReadVector(in, vector);
#define BFWriteAdvVector(vec) BF_WriteAdvVector(out, vec);
#define BFReadAdvVector(vec) BF_ReadAdvVector(in, vec, ver);

void BF_ReadString(std::istream &in, std::string &retval);
void BF_WriteString(std::ostream &out, std::string &str);



template <class L1TYPE> void RemoveIndex(std::vector<L1TYPE> &arr, unsigned int idx)
{
	for (unsigned int i = idx; i < arr.size()-1; i++)
		arr[i] = arr[i+1];
	arr.resize(arr.size()-1);
}

template <class L2TYPE> void BF_WriteVector(std::ostream &out, std::vector<L2TYPE> &arr)
{
	int cnt = arr.size();
	BFWrite(cnt, int)
	out.write(reinterpret_cast<char*>(&arr.front()), sizeof(L2TYPE)* cnt);
}

template <class L3TYPE> void BF_ReadVector(std::istream &in, std::vector<L3TYPE> &arr)
{
	int cnt;
	BFRead(cnt, int)
	arr.resize(cnt);
	in.read(reinterpret_cast<char*>(&arr.front()), sizeof(L3TYPE)* cnt);
}

template <class L4TYPE> void BF_WriteAdvVector(std::ostream &out, std::vector<L4TYPE> &arr)
{
	int cnt = arr.size();
	BFWrite(cnt, int)

	for (int i = 0; i < cnt; i++)
		arr[i].Write(out);
}

template <class L5TYPE> void BF_ReadAdvVector(std::istream &in, std::vector<L5TYPE> &arr, int ver)
{
	int cnt;
	BFRead(cnt, int)
	arr.resize(cnt);

	for (int i = 0; i < cnt; i++)
		arr[i].Read(in, ver);
}

template <class L6TYPE> int FindInList(std::vector<L6TYPE> &haystack, const L6TYPE &needle)
{
	for (unsigned int i = 0; i < haystack.size(); i++)
		if (haystack[i] == needle)
			return i;
	return -1;
}


struct pcs_vertex
{
	vector3d point;
	vector3d norm;
	float u;
	float v;
	float facet_angle;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	pcs_vertex() : u(0.0), v(0.0), facet_angle(-1) {}
	
};

inline bool operator == (const pcs_vertex&t, const pcs_vertex&o){
	return  t.point == o.point&&
		t.norm == o.norm&&
		t.u == o.u&&
		t.v == o.v&&
		t.facet_angle == o.facet_angle;
}

namespace std {
	template<>
	struct hash<pcs_vertex> 	{
		typedef pcs_vertex argument_type;
		typedef std::size_t value_type;

		value_type operator()(argument_type const& v) const {
			value_type const h1(std::hash<vector3d>()(v.point));
			value_type const h2(std::hash<vector3d>()(v.norm));
			value_type const h3(std::hash<float>()(v.u));
			value_type const h4(std::hash<float>()(v.v));
			value_type const h5(std::hash<float>()(v.facet_angle));
			return h1 ^ (h2 << 7) ^ (h3 << 13) ^ (h4 << 17) ^ (h4 << 5) ^ (h5 << 19);
		}
	};
}


struct pcs_polygon
{
	std::vector<pcs_vertex> verts;
	int texture_id;
	vector3d norm;

		vector3d centeroid; 

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	pcs_polygon() : texture_id(-1) {}
	
};

inline bool operator==(const pcs_polygon&t, const pcs_polygon&o){
	return t.verts == o.verts&&
		t.texture_id == o.texture_id&&
		t.norm == o.norm &&
		t.centeroid == o.centeroid;
}

enum { MNONE=0, ROTATE };
enum { ANONE=0, MV_X, MV_Y, MV_Z };

class PCS_Model;

struct pcs_sobj
{
		int parent_sobj;

		float radius;
	float radius_override;
	bool radius_overridden;
	vector3d offset;

	vector3d geometric_center;
	vector3d bounding_box_min_point;
	vector3d bounding_box_max_point;
	vector3d bounding_box_min_point_override;
	vector3d bounding_box_max_point_override;
	bool bounding_box_min_point_overridden;
	bool bounding_box_max_point_overridden;


		std::string name;
	std::string properties;

	int movement_type;
	int movement_axis;

	std::vector<pcs_polygon> polygons;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	pcs_sobj() : parent_sobj(-1), radius(0.0), radius_override(0.0f), radius_overridden(false), bounding_box_min_point_overridden(false), bounding_box_max_point_overridden(false), movement_type(MNONE), movement_axis(ANONE) {}
	void GenerateBBoxes() { 
				for (unsigned int i = 0; i < polygons.size(); i++) 
				{ 
					for (unsigned int j = 0; j < polygons[i].verts.size(); j++) 
					{ 
						ExpandBoundingBoxes(bounding_box_max_point, bounding_box_min_point, polygons[i].verts[j].point);
					} 
				} 
			}
	void GenerateRadius() {
		radius = FindObjectRadius(bounding_box_max_point, bounding_box_min_point, geometric_center);
	}

		
	std::vector<ogl_vertex_buffer> vertex_buffer;
	std::vector<ogl_vertex_buffer> line_vertex_buffer;
	void Transform(PCS_Model& model, int idx, const matrix& transform, const vector3d& translation, bool transform_pivot, bool fixed_pivot);

	void make_vertex_buffer(int tid, int texture_slot); 	void destroy_vertex_buffer();
	private:
		void TransformBefore(PCS_Model& model, int idx);
		void TransformAfter(PCS_Model& model, int idx, const matrix& transform, const vector3d& translation, bool transform_pivot, bool fixed_pivot);
};

inline bool operator == (const pcs_sobj&t, const pcs_sobj&o){
	return 	t.parent_sobj == o.parent_sobj&&
		t.radius == o.radius&&
		t.radius_override == o.radius_override&&
		t.radius_overridden == o.radius_overridden&&
		t.offset == o.offset&&
		t.geometric_center == o.geometric_center&&
		t.bounding_box_min_point == o.bounding_box_min_point&&
		t.bounding_box_min_point_overridden == o.bounding_box_min_point_overridden&&
		t.bounding_box_min_point_override == o.bounding_box_min_point_override&&
		t.bounding_box_max_point == o.bounding_box_max_point&&
		t.bounding_box_max_point_overridden == o.bounding_box_max_point_overridden&&
		t.bounding_box_max_point_override == o.bounding_box_max_point_override&&
		t.name == o.name&&
		t.properties == o.properties&&
		t.movement_type == o.movement_type&&
		t.movement_axis == o.movement_axis&&
		t.polygons == o.polygons;
}


struct pcs_crs_sect
{
	float depth, radius;

	pcs_crs_sect() : depth(0.0), radius(0.0) {}

};

inline bool operator==(const pcs_crs_sect&t, const pcs_crs_sect&o){
	return t.depth == o.depth && t.radius == o.radius;
}


struct pcs_eye_pos
{
	int sobj_number;      	vector3d sobj_offset;   	vector3d normal;

	pcs_eye_pos() : sobj_number(-1), normal(0,0,1) {}
	void Transform(const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_eye_pos&t, const pcs_eye_pos&o){
	return t.sobj_number == o.sobj_number && t.sobj_offset == o.sobj_offset && t.normal == o.normal;
}



struct pcs_special
{
	std::string name;
	std::string properties;
	vector3d point;
    float radius;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	pcs_special() : properties("$special=subsystem"), radius(0.0) {}
	void Transform(PCS_Model& model, const matrix& transform, const vector3d& translation);
};


inline bool operator==(const pcs_special&t, const pcs_special&o){
	return t.properties == o.properties && t.point == o.point && t.radius == o.radius;
}



struct pcs_hardpoint 
{
	vector3d point;
	vector3d norm;
	pcs_hardpoint():norm(0,0,1){}
	void Transform(const matrix& transform, const vector3d& translation);
};
inline bool operator==(const pcs_hardpoint&t, const pcs_hardpoint&o){
	return t.point == o.point && t.norm == o.norm;
}

enum { GUN, MISSILE };

struct pcs_slot 
{
	int type; 	std::vector<pcs_hardpoint> muzzles;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	pcs_slot() : type(GUN) {}
	void Transform(const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_slot&t, const pcs_slot&o){
	return t.type == o.type && t.muzzles == o.muzzles;
}


struct pcs_turret
{
	int type; 	int sobj_parent;     int sobj_par_phys;     
    vector3d turret_normal;
	std::vector<vector3d> fire_points;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	pcs_turret() : type(GUN), sobj_parent(-1), sobj_par_phys(-1) {}
	void Transform(const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_turret&t, const pcs_turret&o){
	return t.type == o.type && 
		t.sobj_parent == o.sobj_parent && 
		t.sobj_par_phys == o.sobj_par_phys && 
		t.turret_normal == o.turret_normal && 
		t.fire_points == o.fire_points;
}


struct pcs_dock_point
{
	std::string properties; 	std::vector<int> paths;
	std::vector<pcs_hardpoint> dockpoints;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	void Transform(PCS_Model& model, const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_dock_point&t, const pcs_dock_point&o){
	return t.properties == o.properties && 
		t.paths == o.paths && 
		t.dockpoints == o.dockpoints;
}


struct pcs_thrust_glow
{	
	vector3d pos;
    vector3d norm;       float radius;

	pcs_thrust_glow() : norm(0,0,-1), radius(0.0) {}
	pcs_thrust_glow(vector3d apos, vector3d anorm, float arad) : pos(apos), norm(anorm), radius(arad) {}
	void Transform(const matrix& transform, const vector3d& translation);
};


inline bool operator==(const pcs_thrust_glow&t, const pcs_thrust_glow&o){
	return t.pos == o.pos && 
		t.norm == o.norm && 
		t.radius == o.radius;
}

struct pcs_thruster
{
	std::vector<pcs_thrust_glow> points;
	std::string properties;
	void Transform(const matrix& transform, const vector3d& translation);

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
};

inline bool operator==(const pcs_thruster&t, const pcs_thruster&o){
	return t.points == o.points && 
		t.properties == o.properties;
}


struct pcs_shield_triangle
{
	vector3d face_normal;
	vector3d corners[3];
	void Transform(PCS_Model& model, const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_shield_triangle&t, const pcs_shield_triangle&o){
	return t.face_normal == o.face_normal && 
		t.corners[0] == o.corners[0] && 
		t.corners[1] == o.corners[1] && 
		t.corners[2] == o.corners[2];
}


struct pcs_insig_face
{
	vector3d verts[3];
	float u[3];
	float v[3];

	pcs_insig_face() { memset(this, 0, sizeof(pcs_insig_face)); }
	void Transform(const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_insig_face&t, const pcs_insig_face&o){
	return t.verts[0] == o.verts[0] &&
		t.verts[1] == o.verts[1] &&
		t.verts[2] == o.verts[2] &&
		t.u[0] == o.u[0] && t.v[0] == o.v[0] &&
		t.u[1] == o.u[1] && t.v[1] == o.v[1] &&
		t.u[2] == o.u[2] && t.v[2] == o.v[2];
}

struct pcs_insig_generator
{
	vector3d pos;
	vector3d forward;
	vector3d up;
	float radius;
	float distance;
	int subdivision;
	float merge_eps;
	pcs_insig_generator() : forward(-1,0,0), up(0,1,0), radius(3.0f), distance(0.005f), subdivision(128), merge_eps(0.9999f) {}
	void Transform(const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_insig_generator&t, const pcs_insig_generator&o){
	return t.pos == o.pos && t.forward == o.forward && t.up == o.up &&
		t.radius == o.radius && t.merge_eps == o.merge_eps;
}

struct pcs_insig
{
	int lod;
	vector3d offset; 	std::vector<pcs_insig_face> faces;

	pcs_insig_generator generator;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	bool Generate(const std::vector<pcs_polygon>& polys, const float epsilon);
	static bool outside_viewport(const std::vector<vector3d>& verts);
	static bool inside_polygon(const vector3d& v, const std::vector<vector3d>& verts);
	static float interpolate_z(const vector3d& v, const std::vector<vector3d>& verts);
	static std::vector<vector3d> clip(const std::vector<vector3d>& verts);
	void Transform(const matrix& transform, const vector3d& translation);

	pcs_insig() : lod(0) {} 
};

inline bool operator==(const pcs_insig&t, const pcs_insig&o){
	return t.lod == o.lod && t.offset == o.offset && t.faces == o.faces && t.generator == o.generator;
}



struct pcs_pvert
{
	vector3d pos;
	float radius;

	pcs_pvert() : radius(0.0) {}
	void Transform(const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_pvert&t, const pcs_pvert&o){
	return t.pos == o.pos && 
		t.radius == o.radius;
}

struct pcs_path
{
	std::string name;
	std::string parent;
	std::vector<pcs_pvert> verts;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	void Transform(const matrix& transform, const vector3d& translation);
};

inline bool operator==(const pcs_path&t, const pcs_path&o){
	return t.name == o.name && 
		t.parent == o.parent && 
		t.verts == o.verts;
}



struct pcs_glow_array  
{ 
	int disp_time;
	int on_time; 
	int off_time; 
	int obj_parent;  
	int LOD; 
	int type; 
	std::string properties;
	std::vector<pcs_thrust_glow> lights;

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);
	pcs_glow_array() : disp_time(0), on_time(0), off_time(0), obj_parent(0), LOD(0), type(0), lights() {}
	void Transform(const matrix& transform, const vector3d& translation);
}; 

inline bool operator==(const pcs_glow_array&t, const pcs_glow_array&o){
	return t.disp_time == o.disp_time && 
		t.on_time == o.on_time && 
		t.off_time == o.off_time && 
		t.obj_parent == o.obj_parent && 
		t.LOD == o.LOD && 
		t.type == o.type && 
		t.properties == o.properties && 
		t.lights == o.lights;
}


struct header_data{
	header_data()
		:max_radius(0.0f),max_radius_override(0.0f),max_radius_overridden(false), min_bounding(0,0,0),max_bounding(0,0,0),min_bounding_overridden(false), max_bounding_overridden(false), mass(0.0f), mass_center(0,0,0)
	{
		memset(MOI,0,sizeof(float)*9);
		MOI[0][0]=1.0f;
		MOI[1][1]=1.0f;
		MOI[2][2]=1.0f;
	}

	header_data(const header_data&h){
		(*this)=h;
	}
	const header_data&operator=(const header_data&h){
		max_radius = h.max_radius;
		max_radius_override = h.max_radius_override;
		max_radius_overridden = h.max_radius_overridden;
		min_bounding = h.min_bounding;
		max_bounding = h.max_bounding;
		min_bounding_override = h.min_bounding_override;
		max_bounding_override = h.max_bounding_override;
		min_bounding_overridden = h.min_bounding_overridden;
		max_bounding_overridden = h.max_bounding_overridden;
		detail_levels = h.detail_levels;
		debris_pieces = h.debris_pieces;
		mass = h.mass;
		mass_center = h.mass_center;
		memcpy(MOI,h.MOI,sizeof(float)*9);
		cross_sections = h.cross_sections;
		return *this;
	}
				float max_radius;           		float max_radius_override;  		float max_radius_overridden;

		vector3d min_bounding;       		vector3d max_bounding;         		vector3d min_bounding_override;       		vector3d max_bounding_override;         		bool min_bounding_overridden;
		bool max_bounding_overridden;


		std::vector<int> detail_levels; 												std::vector<int> debris_pieces; 
		float mass;			vector3d mass_center;

		float MOI[3][3]; 						 
		std::vector<pcs_crs_sect> cross_sections; 												  
};
inline bool operator == (const header_data&t, const header_data&h){
	return t.max_radius == h.max_radius &&
		t.max_radius_override == h.max_radius_override &&
		t.max_radius_overridden == h.max_radius_overridden &&
		t.min_bounding == h.min_bounding &&
		t.max_bounding == h.max_bounding &&
		t.min_bounding_override == h.min_bounding_override &&
		t.max_bounding_override == h.max_bounding_override &&
		t.min_bounding_overridden == h.min_bounding_overridden &&
		t.max_bounding_overridden == h.max_bounding_overridden &&
		t.detail_levels == h.detail_levels &&
		t.debris_pieces == h.debris_pieces &&
		t.mass == h.mass &&
		t.mass_center == h.mass_center &&
		!memcmp(t.MOI,h.MOI,sizeof(float)*9) &&
		t.cross_sections == h.cross_sections;
}


struct pmf_bsp_cache
{
	std::vector<char> bsp_data;
	bool changed;

	pmf_bsp_cache() : changed(false) {}

	void decache() 	{
		bsp_data.clear();
		changed = true;
	}

	void Read(std::istream& in, int ver);
	void Write(std::ostream& out);

	~pmf_bsp_cache() {}
};


#endif 

```

## pcs_pmf_dae.cpp

```cpp
#include "pcs_file.h"
#include "DAEHandler.h"

int PCS_Model::LoadFromDAE(std::string filename, AsyncProgress* progress, bool mirror_x, bool mirror_y, bool mirror_z) {
	DAEHandler dae_handler(filename, this, progress, mirror_x, mirror_y, mirror_z);
	return dae_handler.populate();
}

int PCS_Model::SaveToDAE(std::string filename, AsyncProgress* progress, int helpers, int props_as_helpers) {
	DAESaver dae_handler(filename, this, helpers, props_as_helpers, progress);
	return dae_handler.save();
}
```

## pcs_pmf_pof.cpp

```cpp


#include <fstream>
#include <cfloat>
#include "pcs_file.h"
#include "POFHandler.h"
#include "BSPHandler.h"
#include "pcs_pof_bspfuncs.h"

#include <boost/scoped_ptr.hpp>

#include "pcs2.h"


int PCS_Model::SaveToPOF(std::string filename, AsyncProgress* progress)
{
	PCS_Model::BSP_MAX_DEPTH = 0;
	PCS_Model::BSP_NODE_POLYS = 1;
	PCS_Model::BSP_TREE_TIME = 0;
	PCS_Model::BSP_COMPILE_ERROR = false;
	POF poffile;
	unsigned int i,j,k,l;
	progress->setTarget(6 + light_arrays.size() + ai_paths.size() + insignia.size() + shield_mesh.size() + 
					thrusters.size() + docking.size() + turrets.size() + weapons.size() + special.size() +
					eyes.size() + model_info.size() + subobjects.size() + textures.size());
	char cstringtemp[256];


		progress->incrementWithMessage("Writing Header Pt1");

		std::vector<cross_section> sections;
	sections.resize(header.cross_sections.size());

	for (i = 0; i < header.cross_sections.size(); i++)
	{
		sections[i].depth = header.cross_sections[i].depth;
		sections[i].radius = header.cross_sections[i].radius;
	}
	poffile.HDR2_Set_CrossSections(header.cross_sections.size(), sections);

		progress->incrementWithMessage("Writing Header Pt2");

		poffile.ACEN_Set_acen(POFTranslate(autocentering));

	
		progress->incrementWithMessage("Writing Acen");
	
	
		progress->incrementWithMessage("Writing Textures");
	for (i = 0; i < textures.size(); i++)
		poffile.TXTR_AddTexture(textures[i]);

	
	
	wxLongLong time = wxGetLocalTimeMillis();
	bool bsp_compiled = false;
	header.max_radius = 0.0f;
	for (i = 0; i < subobjects.size(); i++)
	{
											sprintf(cstringtemp, "Submodel %d: %s", i, subobjects[i].name.c_str());
		progress->incrementWithMessage(cstringtemp);
	
				boost::scoped_ptr<OBJ2> obj(new OBJ2);
		obj->submodel_number = i;
		if (!PMFObj_to_POFObj2(i, *obj, bsp_compiled, header.max_radius))
		{
			return 2; 		}
		poffile.OBJ2_Add(*obj); 	}
	time = wxGetLocalTimeMillis() - time;

		can_bsp_cache = true;
	bsp_cache.resize(subobjects.size());
	for (i = 0; i < subobjects.size(); i++)
		poffile.OBJ2_Get_BSPData(i, bsp_cache[i].bsp_data);


		

	int idx = GetModelInfoCount();
	char cstrtmp[256];
	wxString strtmp = PCS2_VERSION;
	sprintf(cstrtmp, "PMFSaveToPOF: Compiled on %s with %s\nmax BSP depth was %d\nmost polys in a single node was %d\nTotal Compile time was %ldms, tree generation time was %ldms", std::string(strtmp.mb_str()).c_str(), std::string(PCS2_COMP_VERSION.mb_str()).c_str(), PCS_Model::BSP_MAX_DEPTH,PCS_Model::BSP_NODE_POLYS, time.ToLong(), PCS_Model::BSP_TREE_TIME.ToLong());
	
	bool found = false;
	for (i = 0; i < model_info.size() && !found; i++)
	{
		if (strstr(model_info[i].c_str(), "PMFSaveToPOF") != NULL)
		{
			found = true;
			if (bsp_compiled) 				model_info[i] = cstrtmp;
		}
	}

	if (!found)
		AddModelInfo(cstrtmp);

	j = 0;
	for (i = 0; i < model_info.size(); i++)
		j += model_info[i].length() + 1;
	
	boost::scoped_ptr<char> pinf(new char[j]);
	memset(pinf.get(), 0, j);
	j = 0;

	for (i = 0; i < model_info.size(); i++)
	{
				sprintf(cstringtemp, "Writing String %d", i); 
		progress->incrementWithMessage(cstringtemp);

		strncpy(pinf.get()+j, model_info[i].c_str(), model_info[i].length());
		j+= model_info[i].length() + 1;
	}
	poffile.PINF_Set(pinf.get(), j);

	if (found)
		model_info.resize(idx); 
	
	for (i = 0; i < eyes.size(); i++)
	{
				sprintf(cstringtemp, "Writing Eye %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.EYE_Add_Eye(eyes[i].sobj_number, 
							POFTranslate(eyes[i].sobj_offset), 
							POFTranslate(eyes[i].normal));
	}


	
	for (i = 0; i < special.size(); i++)
	{
				sprintf(cstringtemp, "Writing Special %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.SPCL_AddSpecial(special[i].name, special[i].properties, 
									POFTranslate(special[i].point), special[i].radius);
	}

	k = l = 0;
		for (i = 0; i < weapons.size(); i++)
	{
				sprintf(cstringtemp, "Writing Weapon %d", i);
		progress->incrementWithMessage(cstringtemp);
		if (weapons[i].type == GUN)
		{
			poffile.GPNT_AddSlot();

			for (j = 0; j < weapons[i].muzzles.size(); j++)
			{
				poffile.GPNT_AddPoint(k, POFTranslate(weapons[i].muzzles[j].point),
										 POFTranslate(weapons[i].muzzles[j].norm));
			}
			k++;
		}
		else
		{	poffile.MPNT_AddSlot();

			for (j = 0; j < weapons[i].muzzles.size(); j++)
			{
				poffile.MPNT_AddPoint(l, POFTranslate(weapons[i].muzzles[j].point),
										 POFTranslate(weapons[i].muzzles[j].norm));
			}
			l++;
		}
	}

		k = l = 0;

	for (i = 0; i < turrets.size(); i++)
	{
				sprintf(cstringtemp, "Writing Turret %d", i);
		progress->incrementWithMessage(cstringtemp);
		if (turrets[i].type == GUN)
		{
			poffile.TGUN_Add_Bank(turrets[i].sobj_parent, 
								  turrets[i].sobj_par_phys, 
								  POFTranslate(turrets[i].turret_normal));
			for (j = 0; j < turrets[i].fire_points.size(); j++)
			{
				poffile.TGUN_Add_FirePoint(k, POFTranslate(turrets[i].fire_points[j]));
			}
			k++;
		}
		else
		{
			poffile.TMIS_Add_Bank(turrets[i].sobj_parent, 
								  turrets[i].sobj_par_phys, 
								  POFTranslate(turrets[i].turret_normal));
			for (j = 0; j < turrets[i].fire_points.size(); j++)
			{
				poffile.TMIS_Add_FirePoint(l, POFTranslate(turrets[i].fire_points[j]));
			}
			l++;
		}
	}

		for (i = 0; i < docking.size(); i++)
	{
				sprintf(cstringtemp, "Writing Docking %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.DOCK_Add_Dock(docking[i].properties);

		for (j = 0; j < docking[i].dockpoints.size(); j++)
		{
			poffile.DOCK_Add_Point(i, POFTranslate(docking[i].dockpoints[j].point), 
									  POFTranslate(docking[i].dockpoints[j].norm));
		}

		for (j = 0; j < docking[i].paths.size(); j++)
		{
			poffile.DOCK_Add_SplinePath(i, docking[i].paths[j]);
		}
	}

		for (i = 0; i < thrusters.size(); i++)
	{
				sprintf(cstringtemp, "Writing Thruster %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.FUEL_Add_Thruster(thrusters[i].properties);

		for (j = 0; j < thrusters[i].points.size(); j++)
		{
			poffile.FUEL_Add_GlowPoint(i, thrusters[i].points[j].radius,
										  POFTranslate(thrusters[i].points[j].pos),
										  POFTranslate(thrusters[i].points[j].norm));
		}
	}

		int fcs[3], nbs[3];
	std::vector<vector3d> points(shield_mesh.size()*3);
	vector3d shldtvect;

		l = 0;
	for (i = 0; i < shield_mesh.size(); i++)
	{
		for (j = 0; j < 3; j++)
		{
			bool found_corner = false;
			for (auto& p : points)
			{
				if (p == POFTranslate(shield_mesh[i].corners[j]))
				{
					found_corner = true;
					break;
				}
			}
			if (!found_corner)
			{
				if (l >= points.size())
					points.resize(points.size()*2);
				points[l] = POFTranslate(shield_mesh[i].corners[j]);
				l++;
			}
		}
	}
	points.resize(l);

		for (i = 0; i < shield_mesh.size(); i++)
	{
				sprintf(cstringtemp, "Writing Shield Tri %d", i);
		progress->incrementWithMessage(cstringtemp);
				for (j = 0; j < 3; j++)
		{
			shldtvect = POFTranslate(shield_mesh[i].corners[j]);
			fcs[j] = FindInList(points, shldtvect);
		}

				j=0;
		for (k = 0; k < shield_mesh.size() && j < 3; k++)
		{
			if (Neighbor(shield_mesh[i], shield_mesh[k]) && i != k)
			{
				nbs[j] = k;
				j++;
			}
		}
				poffile.SHLD_Add_Face(POFTranslate(shield_mesh[i].face_normal), fcs, nbs);
	}

			progress->incrementWithMessage("Writing Shield Points");
	for (i = 0; i < points.size(); i++)
		poffile.SHLD_Add_Vertex(points[i]);

	
	progress->incrementWithMessage("Writing Shield Collision Tree");
		if (poffile.SHLD_Count_Faces() > 0)
	{
		std::vector<pcs_polygon> shldmesh(poffile.SHLD_Count_Faces());

				for (i = 0; i < shldmesh.size(); i++)
		{
			shldmesh[i].verts.resize(3);

			poffile.SHLD_Get_Face(i, shldmesh[i].norm, fcs, nbs);

			for (j = 0; j < 3; j++)
			{
				 poffile.SHLD_Get_Vertex(fcs[j], shldmesh[i].verts[j].point);
				 shldmesh[i].verts[j].norm = shldmesh[i].norm;
			}
			
			shldmesh[i].centeroid = PolygonCenter(shldmesh[i]);
		}

				vector3d smin, smax;
		std::unique_ptr<bsp_tree_node> shld_root = MakeTree(shldmesh, smax, smin);

				int sldc_size = CalcSLDCTreeSize(shld_root.get());
		std::vector<char> sldc;
		sldc.resize(sldc_size);
		
		PackTreeInSLDC(shld_root.get(), 0, &sldc.front(), sldc_size);

		poffile.SLDC_SetTree(std::move(sldc)); 	}

	
	vector3d uv, vv;
	float *u = (float *)&uv, *v = (float *)&vv;
	for (i = 0; i < insignia.size(); i++)
	{
				sprintf(cstringtemp, "Writing Insignia %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.INSG_Add_insignia(insignia[i].lod, POFTranslate(insignia[i].offset));

		for (j = 0; j < insignia[i].faces.size(); j++)
		{
			for (k = 0; k < 3; k++)
			{
				while ((l = poffile.INST_Find_Vert(i, POFTranslate(insignia[i].faces[j].verts[k]))) == (unsigned)-1)
				{
					poffile.INSG_Add_Insig_Vertex(i, POFTranslate(insignia[i].faces[j].verts[k]));
				} 
				fcs[k] = l;
				u[k] = insignia[i].faces[j].u[k];
				v[k] = insignia[i].faces[j].v[k];
			}
			poffile.INSG_Add_Insig_Face(i, fcs, uv, vv);
		}
	}

		for (i = 0; i < ai_paths.size(); i++)
	{
				sprintf(cstringtemp, "Writing Path %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.PATH_Add_Path(ai_paths[i].name, ai_paths[i].parent);

		for (j = 0; j < ai_paths[i].verts.size(); j++)
		{
			poffile.PATH_Add_Vert(i, POFTranslate(ai_paths[i].verts[j].pos), 
									 ai_paths[i].verts[j].radius);
		}
	}

		pcs_glow_array *gla;
	for (i = 0; i < light_arrays.size(); i++)
	{
				sprintf(cstringtemp, "Writing Glow %d", i);
		progress->incrementWithMessage(cstringtemp);
		gla = &light_arrays[i];
		poffile.GLOW_Add_LightGroup(gla->disp_time, gla->on_time, gla->off_time,
								    gla->obj_parent, gla->LOD, gla->type, gla->properties);
		for (j = 0; j < gla->lights.size(); j++)
		{
			poffile.GLOW_Add_GlowPoint(i, gla->lights[j].radius,
										  POFTranslate(gla->lights[j].pos),
										  POFTranslate(gla->lights[j].norm));
		}
	}

		
		vector3d minbox, maxbox, tmpmin, tmpmax;
	poffile.OBJ2_Get_BoundingMax(0, maxbox);
	poffile.OBJ2_Get_BoundingMin(0, minbox);

	for (i = 1; i < poffile.OBJ2_Count(); i++)
	{
		vector3d sobj_offset(POFTranslate(OffsetFromParent(i)));
		poffile.OBJ2_Get_BoundingMax(i, tmpmax);
		poffile.OBJ2_Get_BoundingMin(i, tmpmin);
		ExpandBoundingBoxes(maxbox, minbox, tmpmax + sobj_offset);
		ExpandBoundingBoxes(maxbox, minbox, tmpmin + sobj_offset);

	}

	for (i = 0; i < poffile.SHLD_Count_Vertices(); i++)
	{
		poffile.SHLD_Get_Vertex(i, tmpmax);
		ExpandBoundingBoxes(maxbox, minbox, tmpmax);
	}

			poffile.HDR2_Set_MinBound(header.min_bounding_overridden ? header.min_bounding_override : minbox);
	poffile.HDR2_Set_MaxBound(header.max_bounding_overridden ? header.max_bounding_override : maxbox);
	this->header.max_bounding = minbox;
	this->header.min_bounding = maxbox;

	poffile.HDR2_Set_MaxRadius(header.max_radius_overridden ? header.max_radius_override : header.max_radius);
	poffile.HDR2_Set_Details(header.detail_levels.size(), header.detail_levels);
	poffile.HDR2_Set_Debris(header.debris_pieces.size(), header.debris_pieces);
	poffile.HDR2_Set_Mass(header.mass);
	poffile.HDR2_Set_MassCenter(POFTranslate(header.mass_center));
	poffile.HDR2_Set_MomentInertia(header.MOI);
	poffile.HDR2_Set_SOBJCount(GetSOBJCount());

	std::ofstream out(filename.c_str(), std::ios::out | std::ios::binary);

	if (!poffile.SavePOF(out))
		return 1;

	return 0;
}



int PCS_Model::LoadFromPOF(std::string filename, AsyncProgress* progress)
{
	this->Reset();
	char cstringtemp[256];
	progress->setMessage("Opening and Reading POF");
	progress->Notify();

	std::ifstream infile(filename.c_str(), std::ios::in | std::ios::binary);
	if (!infile)
		return 1;

	POF poffile(infile);
	progress->setTarget(4 + poffile.SPCL_Count() + poffile.GPNT_SlotCount() + poffile.MPNT_SlotCount() + poffile.TGUN_Count_Banks() + poffile.TMIS_Count_Banks() +
					poffile.DOCK_Count_Docks() + poffile.FUEL_Count_Thrusters() + poffile.INSG_Count_Insignia() + poffile.PATH_Count_Paths() + 
					poffile.GLOW_Count_LightGroups() + poffile.OBJ2_Count());

		progress->incrementWithMessage("Getting Header");

	header.max_radius = poffile.HDR2_Get_MaxRadius();
	header.max_radius_override = header.max_radius;
	header.min_bounding = poffile.HDR2_Get_MinBound();
	header.max_bounding = poffile.HDR2_Get_MaxBound();
	POFTranslateBoundingBoxes(header.min_bounding, header.max_bounding);
	header.min_bounding_override = header.min_bounding;
	header.max_bounding_override = header.max_bounding;

	unsigned int i, j, k;
	int scratch; 	poffile.HDR2_Get_Details(scratch, header.detail_levels);
	poffile.HDR2_Get_Debris(scratch, header.debris_pieces);

	header.mass = poffile.HDR2_Get_Mass();
	header.mass_center = POFTranslate(poffile.HDR2_Get_MassCenter());
	poffile.HDR2_Get_MomentInertia(header.MOI);

		std::vector<cross_section> sections;
	poffile.HDR2_Get_CrossSections(scratch, sections);
	
	if (scratch != -1)
	{
		header.cross_sections.resize(scratch);

		for (i = 0; i < header.cross_sections.size(); i++)
		{
			header.cross_sections[i].depth = sections[i].depth;
			header.cross_sections[i].radius = sections[i].radius;
		}
	}
			progress->incrementWithMessage("Getting ACEN, TXTR, PINF, EYE");
	autocentering = POFTranslate(poffile.ACEN_Get_acen());

		textures.resize(poffile.TXTR_Count_Textures());
	std::string tmp_test;
	for (i = 0; i < textures.size(); i++)
	{
		tmp_test = poffile.TXTR_GetTextures(i);
		textures[i] = tmp_test;
	}

		
	model_info = poffile.PINF_Get();

	can_bsp_cache = false;
	for (i = 0; i < model_info.size(); i++)
	{
		if ( 						strstr(model_info[i].c_str(), PCS2_COMP_VERSION.mb_str()))
		{
			can_bsp_cache = true;
			break;
		}
	}


		eyes.resize(poffile.EYE_Count_Eyes());

	for (i = 0; i < eyes.size(); i++)
	{
		poffile.EYE_Get_Eye(i, eyes[i].sobj_number, eyes[i].sobj_offset, eyes[i].normal);
		eyes[i].sobj_offset = POFTranslate(eyes[i].sobj_offset);
		eyes[i].normal = POFTranslate(eyes[i].normal);
	}

		special.resize(poffile.SPCL_Count());

	for (i = 0; i < special.size(); i++)
	{
				sprintf(cstringtemp, "Getting Special %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.SPCL_Get_Special(i, special[i].name, special[i].properties, 
									special[i].point, special[i].radius);
		special[i].point = POFTranslate(special[i].point);
	}


		weapons.resize(poffile.GPNT_SlotCount() + poffile.MPNT_SlotCount());

	for (i = 0; i < poffile.GPNT_SlotCount(); i++)
	{
				sprintf(cstringtemp, "Getting Gun Point %d", i);
		progress->incrementWithMessage(cstringtemp);
		weapons[i].type = GUN;
		weapons[i].muzzles.resize(poffile.GPNT_PointCount(i));

		for (j = 0; j < poffile.GPNT_PointCount(i); j++)
		{
			poffile.GPNT_GetPoint(i, j, weapons[i].muzzles[j].point,
										weapons[i].muzzles[j].norm);
			weapons[i].muzzles[j].point = POFTranslate(weapons[i].muzzles[j].point);
			weapons[i].muzzles[j].norm = POFTranslate(weapons[i].muzzles[j].norm);
		}
	}

	k = poffile.GPNT_SlotCount();
	for (i = 0; i < poffile.MPNT_SlotCount(); i++)
	{
				sprintf(cstringtemp, "Getting Missile Point %d", i);
		progress->incrementWithMessage(cstringtemp);
		weapons[i+k].type = MISSILE;
		weapons[i+k].muzzles.resize(poffile.MPNT_PointCount(i));

		for (j = 0; j < poffile.MPNT_PointCount(i); j++)
		{
			poffile.MPNT_GetPoint(i, j, weapons[i+k].muzzles[j].point,
										weapons[i+k].muzzles[j].norm);
			weapons[i+k].muzzles[j].point = POFTranslate(weapons[i+k].muzzles[j].point);
			weapons[i+k].muzzles[j].norm = POFTranslate(weapons[i+k].muzzles[j].norm);
		}
	}

		turrets.resize(poffile.TGUN_Count_Banks() + poffile.TMIS_Count_Banks());

	for (i = 0; i < poffile.TGUN_Count_Banks(); i++)
	{
				sprintf(cstringtemp, "Getting Gun Turret %d", i);
		progress->incrementWithMessage(cstringtemp);
		turrets[i].type = GUN;
		poffile.TGUN_Get_Bank(i, turrets[i].sobj_parent, 
								 turrets[i].sobj_par_phys, 
								 turrets[i].turret_normal);

		turrets[i].turret_normal = POFTranslate(turrets[i].turret_normal);

		turrets[i].fire_points.resize(poffile.TGUN_Count_Points(i));

		for (j = 0; j < poffile.TGUN_Count_Points(i); j++)
		{
			poffile.TGUN_Get_FirePoint(i, j, turrets[i].fire_points[j]);
			turrets[i].fire_points[j] = POFTranslate(turrets[i].fire_points[j]);
		}
	}

	k = poffile.TGUN_Count_Banks();
	for (i = 0; i < poffile.TMIS_Count_Banks(); i++)
	{
				sprintf(cstringtemp, "Getting Missile Turret %d", i);
		progress->incrementWithMessage(cstringtemp);
		turrets[i+k].type = GUN;
		poffile.TMIS_Get_Bank(i, turrets[i+k].sobj_parent, 
								 turrets[i+k].sobj_par_phys, 
								 turrets[i+k].turret_normal);

		turrets[i+k].turret_normal = POFTranslate(turrets[i+k].turret_normal);

		turrets[i+k].fire_points.resize(poffile.TMIS_Count_Points(i));

		for (j = 0; j < poffile.TMIS_Count_Points(i); j++)
		{
			poffile.TMIS_Get_FirePoint(i, j, turrets[i+k].fire_points[j]);
			turrets[i+k].fire_points[j] = POFTranslate(turrets[i+k].fire_points[j]);
		}
	}

		docking.resize(poffile.DOCK_Count_Docks());

	for (i = 0; i < poffile.DOCK_Count_Docks(); i++)
	{
				sprintf(cstringtemp, "Getting Docking Point %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.DOCK_Get_DockProps(i, docking[i].properties);
		
		docking[i].dockpoints.resize(poffile.DOCK_Count_Points(i));

		for (j = 0; j < poffile.DOCK_Count_Points(i); j++)
		{
			poffile.DOCK_Get_Point(i, j, docking[i].dockpoints[j].point, 
										 docking[i].dockpoints[j].norm);
			docking[i].dockpoints[j].point = POFTranslate(docking[i].dockpoints[j].point);
			docking[i].dockpoints[j].norm = POFTranslate(docking[i].dockpoints[j].norm);
			
		}

		docking[i].paths.resize(poffile.DOCK_Count_SplinePaths(i));

		for (j = 0; j < poffile.DOCK_Count_SplinePaths(i); j++)
		{
			poffile.DOCK_Get_SplinePath(i, j, docking[i].paths[j]);
		}
	}

		thrusters.resize(poffile.FUEL_Count_Thrusters());

	for (i = 0; i < poffile.FUEL_Count_Thrusters(); i++)
	{
				sprintf(cstringtemp, "Getting Thruster %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.FUEL_Get_ThrusterProps(i, thrusters[i].properties);

		thrusters[i].points.resize(poffile.FUEL_Count_Glows(i));
		for (j = 0; j < poffile.FUEL_Count_Glows(i); j++)
		{
			poffile.FUEL_Get_GlowPoint(i, j, thrusters[i].points[j].radius,
											 thrusters[i].points[j].pos,
											 thrusters[i].points[j].norm);
			thrusters[i].points[j].pos = POFTranslate(thrusters[i].points[j].pos);
			thrusters[i].points[j].norm = POFTranslate(thrusters[i].points[j].norm);
		}
	}

			progress->incrementWithMessage("Getting Shields");
	shield_mesh.resize(poffile.SHLD_Count_Faces());
	int fcs[3], nbs[3];
	for (i = 0; i < shield_mesh.size(); i++)
	{
		poffile.SHLD_Get_Face(i, shield_mesh[i].face_normal, fcs, nbs);

		shield_mesh[i].face_normal = POFTranslate(shield_mesh[i].face_normal);\

		for (j = 0; j < 3; j++)
		{
			poffile.SHLD_Get_Vertex(fcs[j], shield_mesh[i].corners[j]);
			shield_mesh[i].corners[j] = POFTranslate(shield_mesh[i].corners[j]);
		}
	}

		insignia.resize(poffile.INSG_Count_Insignia());

	vector3d uv, vv;
	float *u = (float *)&uv, *v = (float *)&vv;

	for (i = 0; i < poffile.INSG_Count_Insignia(); i++)
	{
				sprintf(cstringtemp, "Getting Insignia %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.INSG_Get_Insignia(i, insignia[i].lod, insignia[i].offset);

		insignia[i].offset = POFTranslate(insignia[i].offset);

		insignia[i].faces.resize(poffile.INSG_Count_Faces(i));

		for (j = 0; j < poffile.INSG_Count_Faces(i); j++)
		{
			poffile.INSG_Get_Insig_Face(i, j, fcs, uv, vv);

			for (k = 0; k < 3; k++)
			{
				poffile.INSG_Get_Insig_Vertex(i, fcs[k], insignia[i].faces[j].verts[k]);
				insignia[i].faces[j].verts[k] = POFTranslate(insignia[i].faces[j].verts[k]);

				insignia[i].faces[j].u[k] = u[k];
				insignia[i].faces[j].v[k] = v[k];
			}
		}
	}

		ai_paths.resize(poffile.PATH_Count_Paths());
	for (i = 0; i < poffile.PATH_Count_Paths(); i++)
	{
				sprintf(cstringtemp, "Getting Path %d", i);
		progress->incrementWithMessage(cstringtemp);
		poffile.PATH_Get_Path(i, ai_paths[i].name, ai_paths[i].parent);

		ai_paths[i].verts.resize(poffile.PATH_Count_Verts(i));

		for (j = 0; j < poffile.PATH_Count_Verts(i); j++)
		{
			poffile.PATH_Get_Vert(i, j, ai_paths[i].verts[j].pos, 
										ai_paths[i].verts[j].radius);
			ai_paths[i].verts[j].pos = POFTranslate(ai_paths[i].verts[j].pos);
		}
	}

		light_arrays.resize(poffile.GLOW_Count_LightGroups());
	pcs_glow_array *gla;

	for (i = 0; i < poffile.GLOW_Count_LightGroups(); i++)
	{
				sprintf(cstringtemp, "Getting Glow Array %d", i);
		progress->incrementWithMessage(cstringtemp);
		gla = &light_arrays[i];
		poffile.GLOW_Get_Group(i, gla->disp_time, gla->on_time, gla->off_time,
								  gla->obj_parent, gla->LOD, gla->type, gla->properties);
		gla->lights.resize(poffile.GLOW_Count_Glows(i));

		for (j = 0; j < poffile.GLOW_Count_Glows(i); j++)
		{
			poffile.GLOW_Get_GlowPoint(i, j, gla->lights[j].radius,
											 gla->lights[j].pos,
											 gla->lights[j].norm);
			gla->lights[j].pos = POFTranslate(gla->lights[j].pos);
			gla->lights[j].norm = POFTranslate(gla->lights[j].norm);
		}
	}

		subobjects.resize(poffile.OBJ2_Count());

	if (can_bsp_cache)
		bsp_cache.resize(poffile.OBJ2_Count());
	for (i = 0; i < poffile.OBJ2_Count(); i++)
	{
				sprintf(cstringtemp, "Getting Object %d", i);
		progress->incrementWithMessage(cstringtemp);

		pcs_sobj* obj = &subobjects[i];
		poffile.OBJ2_Get_Parent(i, obj->parent_sobj);
		poffile.OBJ2_Get_Radius(i, obj->radius);
		obj->radius_override = obj->radius;

		poffile.OBJ2_Get_Offset(i, obj->offset);
		obj->offset = POFTranslate(obj->offset);

		poffile.OBJ2_Get_GeoCenter(i, obj->geometric_center);
		obj->geometric_center = POFTranslate(obj->geometric_center);

		poffile.OBJ2_Get_BoundingMin(i, obj->bounding_box_min_point);

		poffile.OBJ2_Get_BoundingMax(i, obj->bounding_box_max_point);

		POFTranslateBoundingBoxes(obj->bounding_box_min_point, obj->bounding_box_max_point);
		obj->bounding_box_min_point_override = obj->bounding_box_min_point;
		obj->bounding_box_max_point_override = obj->bounding_box_max_point;

		poffile.OBJ2_Get_Name(i, obj->name);
		poffile.OBJ2_Get_Props(i, obj->properties);
		int type;
		poffile.OBJ2_Get_MoveType(i, type); 		switch (type)
		{
			case 1:
				obj->movement_type = ROTATE;
				break;
			default:
				obj->movement_type = MNONE;
		}
		poffile.OBJ2_Get_MoveAxis(i, type); 		switch (type)
		{
			case 0:
				obj->movement_axis = MV_X;
				break;
			case 1:
				obj->movement_axis = MV_Z;
				break;
			case 2:
				obj->movement_axis = MV_Y;
				break;
			default:
				obj->movement_axis = ANONE;
		}

				int bspsz;
		char *bspdata = NULL;
		poffile.OBJ2_Get_BSPDataPtr(i, bspsz, bspdata);

		
		obj->polygons.resize(100); 
		unsigned int used_polygons = 0;
		BSP_DefPoints points;
		BSPTransPMF(0, (unsigned char *)bspdata, points, obj->polygons, used_polygons);
		obj->polygons.resize(used_polygons); 
		if (can_bsp_cache)
			poffile.OBJ2_Get_BSPData(i, bsp_cache[i].bsp_data);

							}
	Transform(matrix(), vector3d());
	header.max_radius_overridden = std::fabs(header.max_radius - header.max_radius_override) > 0.0001f;
	header.max_bounding_overridden = header.max_bounding != header.max_bounding_override;
	header.min_bounding_overridden = header.min_bounding != header.min_bounding_override;
	for (auto& sobj : subobjects) {
		sobj.radius_overridden = std::fabs(sobj.radius - sobj.radius_override) > 0.0001f;
		sobj.bounding_box_min_point_overridden = sobj.bounding_box_min_point != sobj.bounding_box_min_point_override;
		sobj.bounding_box_max_point_overridden = sobj.bounding_box_max_point != sobj.bounding_box_max_point_override;
	}
	return 0;
}


bool Neighbor(pcs_shield_triangle &face1, pcs_shield_triangle &face2)
{
	int CommonVerts = 0;

	if (face1.corners[0] == face2.corners[0] ||
		face1.corners[0] == face2.corners[1] ||
		face1.corners[0] == face2.corners[2])
		CommonVerts++;

	if (face1.corners[1] == face2.corners[0] ||
		face1.corners[1] == face2.corners[1] ||
		face1.corners[1] == face2.corners[2])
		CommonVerts++;

	if (face1.corners[2] == face2.corners[0] ||
		face1.corners[2] == face2.corners[1] ||
		face1.corners[2] == face2.corners[2])
		CommonVerts++;

	return (CommonVerts > 1 && CommonVerts < 3); }



bool PCS_Model::PMFObj_to_POFObj2(int src_num, OBJ2 &dst, bool &bsp_compiled, float& model_radius)
{

	pcs_sobj &src = subobjects[src_num];

	dst.submodel_parent = src.parent_sobj;
	dst.offset = POFTranslate(src.offset);
	dst.geometric_center = POFTranslate(src.geometric_center);
	dst.submodel_name = APStoString(src.name);
	dst.properties = APStoString(src.properties);

	switch (src.movement_type)
	{
		case ROTATE:
			dst.movement_type = 1;
			break;
		default:
			dst.movement_type = -1;
	}
	switch (src.movement_axis)
	{
		case MV_X:
			dst.movement_axis = 0;
			break;
		case MV_Z:
			dst.movement_axis = 1;
			break;
		case MV_Y:
			dst.movement_axis = 2;
			break;
		default:
			dst.movement_axis = -1;
	}

	dst.reserved = 0;



	if(!can_bsp_cache || bsp_cache[src_num].changed)
	{

				std::vector<pcs_polygon> clean_list = src.polygons;
		for (size_t i = 0; i < clean_list.size(); i++)
		{
			clean_list[i].norm = POFTranslate(clean_list[i].norm);
			for (size_t j = 0; j < clean_list[i].verts.size(); j++)
			{
				clean_list[i].verts[j].point = POFTranslate(clean_list[i].verts[j].point);
				clean_list[i].verts[j].norm = POFTranslate(clean_list[i].verts[j].norm);
			}
			clean_list[i].centeroid = PolygonCenter(clean_list[i]);
		}

						std::vector<bsp_vert> points_list;
		std::vector<vector3d> pnts;
		std::unordered_map<vector3d, int> point_to_index;
		std::unordered_map<vector3d, int> normal_to_index;
		for (size_t i = 0; i < pnts.size(); i++) {
			point_to_index.insert(std::make_pair(pnts[i], i));
		}
		bsp_vert temp;
		points_list.reserve(clean_list.size());
		for (size_t i = 0; i < clean_list.size(); i++)
		{
			for (size_t j = 0; j < clean_list[i].verts.size(); j++)
			{
				auto point = point_to_index.find(clean_list[i].verts[j].point);
				if (point == point_to_index.end()) {
					point_to_index.insert(std::make_pair(clean_list[i].verts[j].point, points_list.size()));
					points_list.emplace_back();
					points_list.back().point = clean_list[i].verts[j].point;
					pnts.push_back(points_list.back().point);
				}
				auto normal = normal_to_index.find(clean_list[i].verts[j].norm);
				if (normal == normal_to_index.end()) {
					points_list[normal_to_index.size() / 128].norms.push_back(clean_list[i].verts[j].norm);
					normal_to_index.insert(std::make_pair(clean_list[i].verts[j].norm, normal_to_index.size()));
				}
			}
		}



				BSP_DefPoints points;
		MakeDefPoints(points, points_list);
		vector3d AvgNormal;

				std::unique_ptr<bsp_tree_node> root = MakeTree(clean_list, dst.bounding_box_max_point, dst.bounding_box_min_point);

				dst.bsp_data.resize(points.head.size + CalculateTreeSize(root.get(), clean_list));

		if (points.Write(&dst.bsp_data.front()) != points.head.size)
			return false; 
				
				int error_flags = 0;
		PackTreeInBSP(root.get(), points.head.size, &dst.bsp_data.front(), clean_list, normal_to_index, point_to_index, points, dst.geometric_center, dst.bsp_data.size(), error_flags);
		
				if (error_flags != BSP_NOERRORS)
			return false;

				bsp_compiled = true;

				if (can_bsp_cache)
		{
						bsp_cache[src_num].decache();
			bsp_cache[src_num].bsp_data = dst.bsp_data;
			bsp_cache[src_num].changed = false;
		}


	}
	else 	{
		dst.bsp_data = bsp_cache[src_num].bsp_data;
	}
	dst.radius = 0.0f;
	dst.bounding_box_max_point = vector3d(FLT_MIN, FLT_MIN, FLT_MIN);
	dst.bounding_box_min_point = vector3d(FLT_MAX, FLT_MAX, FLT_MAX);

	vector3d global_offset(OffsetFromParent(src_num));
	for(unsigned int i = 0; i<src.polygons.size(); i++){
		for(unsigned int j = 0; j<src.polygons[i].verts.size(); j++){
			ExpandBoundingBoxes(dst.bounding_box_max_point, dst.bounding_box_min_point,  src.polygons[i].verts[j].point);
			float norm = Magnitude(src.polygons[i].verts[j].point);
			if (norm > dst.radius) {
				dst.radius = norm;
			}
			float global_norm = Magnitude(src.polygons[i].verts[j].point + global_offset);
			if (global_norm > model_radius) {
				model_radius = global_norm;
			}

		}
	}
	if (dst.radius == 0.0f) {
		dst.bounding_box_max_point = vector3d();
		dst.bounding_box_min_point = vector3d();
	}
	if (src.radius_overridden) {
		dst.radius = src.radius_override;
	}
	if (src.bounding_box_min_point_overridden) {
		dst.bounding_box_min_point = src.bounding_box_min_point_override;
	}
	if (src.bounding_box_max_point_overridden) {
		dst.bounding_box_max_point = src.bounding_box_max_point_override;
	}
	POFTranslateBoundingBoxes(dst.bounding_box_min_point, dst.bounding_box_max_point);
	return true;
}

```

## pcs_pof_bspfuncs.cpp

```cpp



#include "pcs_pof_bspfuncs.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <wx/stopwatch.h>

#undef max

vector3d POFTranslate(vector3d v)
{
	v.x = -v.x;
	return v;
}


bool operator==(const bsp_vert &one, const bsp_vert &two)
{
	return one.point == two.point;
}




pcs_polygon RebuildCleanPolygon(pcs_polygon &src)
{
	pcs_polygon dst;

	if (src.verts.size() < 3)
		return dst; 	int used = 1;
	dst.norm = src.norm;
	dst.texture_id = src.texture_id;
	dst.verts.resize(src.verts.size());
	dst.verts[0] = src.verts[0];
	vector3d last_point = src.verts[0].point;

	for (unsigned int i = 1; i < src.verts.size(); i++)
	{
		if (i < src.verts.size()-1)
		{
			if (Distance(last_point, src.verts[i].point) > 0.01)
			{
				dst.verts[used] = src.verts[i];
				used++;
			}
		}
		else
		{
			if (Distance(last_point, src.verts[i].point) > 0.01 && Distance(src.verts[i].point, src.verts[0].point) > 0.01)
			{
				dst.verts[used] = src.verts[i];
				used++;
			}
		}
	}
	dst.verts.resize(used);
	return dst;
}


int PackTreeInBSP(bsp_tree_node* root, int offset, char *buffer, std::vector<pcs_polygon> &polygons,
	std::unordered_map<vector3d, int> &norms, std::unordered_map<vector3d, int> &verts, BSP_DefPoints &dpnts, vector3d geo_center, int buffsize, int &error_flags)
{
			if (error_flags != BSP_NOERRORS)
		return 0; 

		if (offset >= buffsize-7)
	{
		error_flags |= BSP_PACK_PREOVERFLOW;
		return 0;
	}
		if (root != NULL && root->used == true)
	{
		error_flags |= BSP_PACK_DOUBLEUSE;
		return 0;
	}

	if (root != NULL && root->counted == false)
	{
		error_flags |= BSP_PACK_UNCOUNTED;
		return 0;
	}

		int size = 0;
	BSP_BlockHeader EndOfFile;
	EndOfFile.id = 0;
	EndOfFile.size = 0;

	BSP_BoundBox Bounding;
	Bounding.head.id = 5;
	Bounding.head.size = Bounding.MySize();

	BSP_TmapPoly tpoly;
	BSP_FlatPoly fpoly;

	BSP_SortNorm snorm;	
	
	if (root == NULL)
	{
		EndOfFile.Write(buffer+offset);
		return 8;
	}
	switch(root->Type)
	{
		case POLY:
						Bounding.max_point = root->bound_max;
			Bounding.min_point = root->bound_min;
			Bounding.Write(buffer+offset+size);
			size += Bounding.MySize();

			if (offset+CalculateTreeSize(root, polygons) > buffsize)
			{
				error_flags |= BSP_PACK_PREPOLYOVERFLOW;
				return 0;
			}
						
						for(unsigned int i = 0; i<root->poly_num.size(); i++){
				if (polygons[root->poly_num[i]].texture_id == -1)
				{
					MakeFlatPoly(fpoly, polygons[root->poly_num[i]], norms, verts, dpnts);

					fpoly.Write(buffer+offset+size);
					size += fpoly.MySize();
				}
				else 
				{
					MakeTmapPoly(tpoly, polygons[root->poly_num[i]], norms, verts, dpnts);

					tpoly.Write(buffer+offset+size);
					size += tpoly.MySize();
				}
			}
						EndOfFile.Write(buffer+offset+size);
			size += EndOfFile.MySize();
			root->used = true;

			if (offset+size > buffsize)
			{
				error_flags |= BSP_PACK_POLYOVERFLOW;
			}
			return size;

		default: 			size = 80;
			memset((char*)&snorm, 0, sizeof(BSP_SortNorm));
			snorm.head.id = 4;
			snorm.head.size = snorm.MySize();
			snorm.plane_point = root->point;
			snorm.plane_normal = root->normal;
			snorm.max_bounding_box_point = root->bound_max;
			snorm.min_bounding_box_point = root->bound_min;

			if (offset+CalculateTreeSize(root, polygons) > buffsize)
			{
				error_flags |= BSP_PACK_PRESPLITOVERFLOW;
				return 0;
			}

			snorm.prelist_offset = size;
			size += PackTreeInBSP(NULL, offset+size, buffer, polygons, norms, verts, dpnts, geo_center, buffsize, error_flags);
				
			snorm.postlist_offset = size;
			size += PackTreeInBSP(NULL, offset + size, buffer, polygons, norms, verts, dpnts, geo_center, buffsize, error_flags);
				
			snorm.online_offset = size;
			size += PackTreeInBSP(NULL, offset + size, buffer, polygons, norms, verts, dpnts, geo_center, buffsize, error_flags);
			
			snorm.front_offset = size;
			size += PackTreeInBSP(root->front.get(), offset+size, buffer, polygons, norms, verts, dpnts, geo_center, buffsize, error_flags);

			snorm.back_offset = size;
			size += PackTreeInBSP(root->back.get(), offset+size, buffer, polygons, norms, verts, dpnts, geo_center, buffsize, error_flags);

			snorm.Write(buffer+offset);

			
									
			root->used = true;
			if (offset+size > buffsize)
			{
				error_flags |= BSP_PACK_SPLITOVERFLOW;
			}
			return size;
	}
	return 0;
}


int CalculateTreeSize(bsp_tree_node* root, std::vector<pcs_polygon> &polygons)
{
	if (root == NULL)
		return 8; 
	int ret_size = 0;
	switch(root->Type)
	{
		case POLY:
						ret_size += 32;
			for(unsigned int i = 0; i<root->poly_num.size(); i++){
				if (polygons[root->poly_num[i]].texture_id == -1)
					ret_size += 44 + 4 * polygons[root->poly_num[i]].verts.size();				else 
					ret_size += 44 + 12 * polygons[root->poly_num[i]].verts.size();			}
			ret_size += 8;
			root->counted = true;
			return ret_size;

		default: 			root->counted = true;
			return 104 + CalculateTreeSize(root->front.get(), polygons) + CalculateTreeSize(root->back.get(), polygons); 	}
	return 0;

}



int CalcSLDCTreeSize(bsp_tree_node* root)
{
	if (root == NULL)
		return 0;
	switch(root->Type)
	{
		case POLY:
			return 33 + root->poly_num.size()*sizeof(int);

		default: 			return 37 + CalcSLDCTreeSize(root->front.get()) + CalcSLDCTreeSize(root->back.get());
	}
	return 0;
}


int PackTreeInSLDC(bsp_tree_node* root, int offset, char *buffer, int bufsz)
{
	if (root == NULL)
		return 0;

	int size = 0, szt;
	SLDC_node_head head;
	SLDC_node_split split;
	switch(root->Type)
	{
		case POLY:
			head.size = 33 + root->poly_num.size()*sizeof(int);
			head.type = 1;
			
						memcpy((buffer+offset+size), (char*)&head.type, sizeof(char));
			size += sizeof(char);

			memcpy((buffer+offset+size), (char*)&head.size, sizeof(int));
			size += sizeof(int);

						memcpy((buffer+offset+size), (char*)&root->bound_min, sizeof(vector3d));
			size += sizeof(vector3d);

			memcpy((buffer+offset+size), (char*)&root->bound_max, sizeof(vector3d));
			size += sizeof(vector3d);
			
						szt = root->poly_num.size();
			memcpy((buffer+offset+size), (char*)&szt, sizeof(int));
			size += sizeof(int);

			for (unsigned int i = 0; i < root->poly_num.size(); i++)
			{
				szt = root->poly_num[i];
				memcpy((buffer+offset+size), (char*)&szt, sizeof(int));
				size += sizeof(int);
			}
			return head.size;

		default: 			size = 37;
			split.header.type = 0;
			split.header.size = size;
			split.bound_min = root->bound_min;
			split.bound_max = root->bound_max;

			split.front_offset = size;
			size += PackTreeInSLDC(root->front.get(), offset+size, buffer, bufsz);

			split.back_offset = size;
			size += PackTreeInSLDC(root->back.get(), offset + size, buffer, bufsz);

			szt = 0;
						memcpy((buffer+offset+szt), (char*)&split.header.type, sizeof(char));
			szt += sizeof(char);

			memcpy((buffer+offset+szt), (char*)&split.header.size, sizeof(int));
			szt += sizeof(int);

						memcpy((buffer+offset+szt), (char*)&split.bound_min, sizeof(vector3d));
			szt += sizeof(vector3d);

			memcpy((buffer+offset+szt), (char*)&split.bound_max, sizeof(vector3d));
			szt += sizeof(vector3d);

						memcpy((buffer+offset+szt), (char*)&split.front_offset, sizeof(int));
			szt += sizeof(int);

			memcpy((buffer+offset+szt), (char*)&split.back_offset, sizeof(int));
			szt += sizeof(int);
	
			return size;
	}
	return 0;
}


void DebugPrintTree(bsp_tree_node* root, std::ostream &out)
{
	if (root == NULL)
		return;
	switch(root->Type)
	{
		case POLY:
			out << "BBOX MAX" << root->bound_max << ", MIN" << root->bound_min << std::endl;
			for(unsigned int i = 0; i<root->poly_num.size(); i++)
				out << "POLYGON " << root->poly_num[i] << std::endl;
			out << "END" << std::endl;
			break;

		default: 			out << "SPLIT MAX" << root->bound_max << ", MIN" << root->bound_min << std::endl;
			out << "  +Plane Point" << root->point << ", Normal" << root->normal << std::endl;
			if (root->front)
			{
				out << "  @Front" << std::endl;
				DebugPrintTree(root->front.get(), out);
			}
			if (root->back)
			{
				out << "  @Back" << std::endl;
				DebugPrintTree(root->back.get(), out);
			}
			break;
	}

}


std::unique_ptr<bsp_tree_node> MakeTree(std::vector<pcs_polygon> &polygons, vector3d &Max, vector3d &Min)
{
	std::vector<int> polylist(polygons.size());
	for (unsigned int i = 0; i < polylist.size(); i++)
	{
		polylist[i] = i;
	}
	MakeBound(Max, Min, polylist, polygons);

		Max = Max +vector3d(0.1f, 0.1f, 0.1f);
	Min = Min -vector3d(0.1f, 0.1f, 0.1f);

	if (polygons.empty()) {
		return std::unique_ptr<bsp_tree_node>((bsp_tree_node*)NULL);
	}

	wxLongLong time = wxGetLocalTimeMillis();
	PCS_Model::BSP_CUR_DEPTH = 0;
	std::unique_ptr<bsp_tree_node> node = GenerateTreeRecursion(polygons, polylist);

	PCS_Model::BSP_TREE_TIME += (wxGetLocalTimeMillis() - time).ToLong();
	return node;
}



class polylist_comparator {
public:
	polylist_comparator(const std::vector<pcs_polygon> *polygons_in, int axis_in)
		: polygons(polygons_in), axis(axis_in) {}
	bool operator()(int a, int b) {
		return (*polygons)[a].centeroid[axis] < (*polygons)[b].centeroid[axis];
	}
private:
	const std::vector<pcs_polygon>* polygons;
	int axis;
};

std::unique_ptr<bsp_tree_node> GenerateTreeRecursion(std::vector<pcs_polygon> &polygons, std::vector<int>&contained)
{
	PCS_Model::BSP_CUR_DEPTH++;
	if(PCS_Model::BSP_MAX_DEPTH < PCS_Model::BSP_CUR_DEPTH)
		PCS_Model::BSP_MAX_DEPTH = PCS_Model::BSP_CUR_DEPTH;
	if (PCS_Model::BSP_CUR_DEPTH > 500)
	{
		PCS_Model::BSP_COMPILE_ERROR = true;
		return std::unique_ptr<bsp_tree_node>((bsp_tree_node*)NULL); 	}
	std::unique_ptr<bsp_tree_node> node(new bsp_tree_node);
	MakeBound(node->bound_max, node->bound_min, contained, polygons);
	if (contained.size() == 1)
	{
				node->Type = POLY;
		node->poly_num = contained;
	}
	else
	{
				vector3d cmax = polygons[contained[0]].centeroid;
		vector3d cmin = polygons[contained[0]].centeroid;
		for (std::vector<int>::iterator it = contained.begin() + 1; it < contained.end(); ++it) {
			ExpandBoundingBoxes(cmax, cmin, polygons[*it].centeroid);
		}
		std::vector<int> front, back;
		if (!Bisect(cmax, cmin, node->point, node->normal, polygons, contained, front, back)) {
			node->Type = POLY;
			node->poly_num = contained;
		} else {
			node->Type = SPLIT;
			node->front = GenerateTreeRecursion(polygons, front);
			node->back = GenerateTreeRecursion(polygons, back);
		}
	}
	PCS_Model::BSP_CUR_DEPTH--;
	return node;
}


bool Bisect(const vector3d& cmax, const vector3d& cmin, 
			vector3d &p_point, vector3d &p_norm,
			const std::vector<pcs_polygon>& polygons,
			std::vector<int>& contained,
			std::vector<int>& front,
			std::vector<int>& back,
			vector3d *centera, vector3d *centerb)
{
	float x,y,z;
	vector3d difference;
	if (centera==NULL || centerb==NULL)
	{
		x = std::fabs(cmax.x-cmin.x);
		y = std::fabs(cmax.y-cmin.y);
		z = std::fabs(cmax.z-cmin.z);

		difference = vector3d(x,y,z);
		difference = difference / 2;
		p_point = cmin + (difference);
	}
	else
	{
		x = std::fabs(centera->x-centerb->x);
		y = std::fabs(centera->y-centerb->y);
		z = std::fabs(centera->z-centerb->z);

		difference = *centera + *centerb;
		p_point = difference / 2;
	}

	int axis;

	if (x >= y && x >= z)
	{
		axis = 0;
		p_norm = MakeVector(1.0, 0.0, 0.0); 	}
	else if (y >= z)
	{
		axis = 1;
		p_norm = MakeVector(0.0, 1.0, 0.0);
	}
	else
	{
		axis = 2;
		p_norm = MakeVector(0.0, 0.0, 1.0);
	}
	if (difference[axis] < 10 * std::numeric_limits<float>::epsilon() * std::max(std::fabs(cmax[axis]), std::fabs(cmin[axis]))) {
		return false;
	}
	polylist_comparator comparator(&polygons, axis);
	std::sort(contained.begin(), contained.end(), comparator);
	int median = contained.size() / 2;
	const pcs_polygon& before = polygons[contained[median - 1]];
	const pcs_polygon& after = polygons[contained[median]];
	float split = (before.centeroid[axis] + after.centeroid[axis]) / 2;
	p_point[axis] = split;
	front.assign(contained.begin(), contained.begin() + median);
	back.assign(contained.begin() + median, contained.end());
	return true;
}



void TriangulateMesh(std::vector<pcs_polygon> &polygons)
{
	std::vector<pcs_polygon> temp, new_polygons;
	unsigned int oldsize, i, j;
	for (i = 0; i < polygons.size(); i++)
	{
		if (polygons[i].verts.size() > 3)
		{
			temp.resize(polygons[i].verts.size() - 2);

						for (j = 0; j < temp.size()-2; j++)
			{
				temp[j].verts.resize(3);
				temp[j].norm = polygons[i].norm;
				temp[j].texture_id = polygons[i].texture_id;
				temp[j].verts[0] = polygons[i].verts[0];
				temp[j].verts[1] = polygons[i].verts[1+j];
				temp[j].verts[2] = polygons[i].verts[2+j];
			}
						polygons[i] = temp[0];

						oldsize = new_polygons.size();
			new_polygons.resize(new_polygons.size()+temp.size()-1);
			for (j = 0; j < temp.size()-1; j++)
			{
				new_polygons[oldsize+j] = temp[j+1];
			}
		}
	}

	oldsize = polygons.size();
	polygons.resize(oldsize+new_polygons.size());
	for (i = 0; i < new_polygons.size(); i++)
	{	
		polygons[oldsize+i] = new_polygons[i];
	}
}



float FindIntersection(vector3d &intersect, vector3d p1, vector3d p2, vector3d plane_point, vector3d plane_normal)
{
	float den = plane_normal.x*(p1.x - p2.x) + plane_normal.y*(p1.y - p2.y) + plane_normal.z*(p1.z - p2.z);
	if (den == 0)
		return 0.0; 	float d = -(plane_point.x*plane_normal.x + plane_point.y*plane_normal.y + plane_point.z*plane_normal.z);
	float num = plane_normal.x*p1.x + plane_normal.y*p1.y + plane_normal.z*p1.z + d;
	
	vector3d temp(p2-p1);
	temp = temp * (num / den);
	intersect = p1 + temp;

			return (num/den);
}


void AddIfNotInList(std::vector<pcs_vertex> &list, pcs_vertex &point)
{
	int idx;
	for (unsigned int i = 0; i < list.size(); i++)
	{
		if (list[i].point == point.point)
			return;
	}
	idx = list.size();
	list.resize(idx+1);
	list[idx] = point;
}



void SplitPolygon(std::vector<pcs_polygon> &polygons, int polynum, vector3d plane_point, vector3d plane_normal, std::vector<pcs_polygon> &newpolys)
{
	std::vector<pcs_polygon> splitpolys(2); 	std::vector<int> pairs;
	std::vector<pcs_vertex> points;
	pairs.resize(polygons[polynum].verts.size() * 2);
	pcs_vertex temp;
	unsigned int i, j = 0;
	float uvdelta;

	for (i = 0; i < polygons[polynum].verts.size() * 2; i += 2)
	{
		pairs[i] = j % polygons[polynum].verts.size();
		pairs[i+1] = (j+1) % polygons[polynum].verts.size();
		j++;
	}

	float dtempa, dtempb;
		for (i = 0; i < pairs.size(); i += 2)
	{
		dtempa = DistanceToPlane(polygons[polynum].verts[pairs[i]].point, plane_point, plane_normal);
		dtempb = DistanceToPlane(polygons[polynum].verts[pairs[i+1]].point, plane_point, plane_normal);
		if ((dtempa <= 0.0001 && dtempa >= -0.0001) || (dtempb <= 0.0001 && dtempb >= -0.0001))
				{

			AddIfNotInList(points, polygons[polynum].verts[pairs[i]]);
			AddIfNotInList(points, polygons[polynum].verts[pairs[i+1]]);
		}
		else 		{

			if (InFrontofPlane(polygons[polynum].verts[pairs[i]].point, plane_point, plane_normal) == 
				InFrontofPlane(polygons[polynum].verts[pairs[i+1]].point, plane_point, plane_normal))
						{
				AddIfNotInList(points, polygons[polynum].verts[pairs[i]]);
				AddIfNotInList(points, polygons[polynum].verts[pairs[i+1]]);
			}
			else
						{
				uvdelta = FindIntersection(temp.point, polygons[polynum].verts[pairs[i]].point, 
						polygons[polynum].verts[pairs[i+1]].point, plane_point, plane_normal);
				temp.norm = polygons[polynum].norm;
				temp.u = uvdelta * (polygons[polynum].verts[pairs[i]].u - polygons[polynum].verts[pairs[i+1]].u);
				temp.v = uvdelta * (polygons[polynum].verts[pairs[i]].v - polygons[polynum].verts[pairs[i+1]].v);

				AddIfNotInList(points, polygons[polynum].verts[pairs[i]]);
				AddIfNotInList(points, temp);
				AddIfNotInList(points, polygons[polynum].verts[pairs[i+1]]);
			}
		}
	}


	
	int in = 0;
	for (i = 0; i < points.size(); i++)
	{
		dtempa = DistanceToPlane(points[i].point, plane_point, plane_normal) ;
		if (dtempa <= 0.0001 && dtempa >= -0.0001)
				{
			AddIfNotInList(splitpolys[0].verts, points[i]);
			AddIfNotInList(splitpolys[1].verts, points[i]);
			
			if (in == 0)
				in = 1;
			else
				in = 0;
		}
		else
		{
			AddIfNotInList(splitpolys[in].verts, points[i]);
		}
	}

		TriangulateMesh(splitpolys);

		polygons[polynum] = splitpolys[0];
	in = newpolys.size();
	newpolys.resize(in+splitpolys.size());
	for (i = 1; i < splitpolys.size(); i++)
	{
		newpolys[in+i] = splitpolys[i];
	}
}


float DistanceToPlane(vector3d point, vector3d plane_point, vector3d plane_normal)
{
	float d = -(plane_point.x*plane_normal.x + plane_point.y*plane_normal.y + plane_point.z*plane_normal.z);
	
	return (point.x*plane_normal.x + point.y*plane_normal.y + point.z*plane_normal.z + d)/
			 sqrt(plane_normal.x*plane_normal.x + plane_normal.y*plane_normal.y + plane_normal.z*plane_normal.z);
}



bool InFrontofPlane(vector3d point, vector3d plane_point, vector3d plane_normal)
{
	return DistanceToPlane(point, plane_point, plane_normal) >= 0;
}


bool Intersects(pcs_polygon &polygon, vector3d plane_point, vector3d plane_normal)
{
	if (polygon.verts.size() < 3)
		return false; 
	bool infront = InFrontofPlane(polygon.verts[0].point, plane_point, plane_normal);

	for (unsigned int i = 1; i < polygon.verts.size(); i++)
	{
		if (DistanceToPlane(polygon.verts[i].point, plane_point, plane_normal) != 0 && 			infront != InFrontofPlane(polygon.verts[i].point, plane_point, plane_normal))
			return true;
	}

	return false;
}



void SplitIntersecting(std::vector<pcs_polygon> &polygons, vector3d plane_point, vector3d plane_normal)
{
	std::vector<pcs_polygon> newpolys;
	unsigned int i;
	for (i = 0; i < polygons.size(); i++)
	{
		if (Intersects(polygons[i], plane_point, plane_normal))
		{
			SplitPolygon(polygons, i, plane_point, plane_normal, newpolys);
		}
	}
	
	int in = polygons.size();
	polygons.resize(in+newpolys.size());
	for (i = 1; i < newpolys.size(); i++)
	{
		polygons[in+i] = newpolys[i];
	}
}





vector3d PolygonCenterFallback(pcs_polygon &polygon)
{
	vector3d empty;

	for (unsigned int i = 0; i < polygon.verts.size(); i++)
	{
		empty += polygon.verts[i].point;
	}

	empty = empty / float(polygon.verts.size());
	return empty;
}



vector3d PolygonCenter(pcs_polygon &polygon)
{

	float TotalArea=0, triarea;
	vector3d Centroid = MakeVector(0,0,0), midpoint;

	for (unsigned int i = 0; i < polygon.verts.size()-2; i++)
	{
		midpoint = polygon.verts[i].point + polygon.verts[i+1].point + polygon.verts[i+2].point;
		midpoint = midpoint/3;

		
		triarea = Magnitude(CrossProduct(polygon.verts[i+1].point-polygon.verts[i].point, 
										 polygon.verts[i+2].point-polygon.verts[i].point)); 		if (triarea == 0)
		{
			return PolygonCenterFallback(polygon);
					}
		midpoint = triarea*midpoint;
		TotalArea += triarea;
		Centroid += midpoint;

	}

	Centroid = float(1.0 / TotalArea) * Centroid;
	return Centroid;

}



void BoundPolygon(vector3d &Max, vector3d &Min, int polygon, std::vector<pcs_polygon> &polygons)
{
	 if (polygon < 0 || (unsigned)polygon > polygons.size() || polygons[polygon].verts.size() < 1)
		 return;
	 Min = Max = polygons[polygon].verts[0].point;
	 vector3d minbuf(-0.01f, -0.01f, -0.01f), maxbuf(0.01f, 0.01f, 0.01f);
	 for (unsigned int i = 1; i < polygons[polygon].verts.size(); i++)
	 {
		 ExpandBoundingBoxes(Max, Min, polygons[polygon].verts[i].point);
	 }

		Max = Max + maxbuf;
	Min = Min + minbuf;
}


void MakeBound(vector3d &Max, vector3d &Min, std::vector<int> &polylist, std::vector<pcs_polygon> &polygons)
{
	if (polylist.size() < 1 || polygons.size() < 1)
		return;

	BoundPolygon(Max, Min, polylist[0], polygons);
	vector3d pmin, pmax, minbuf(-0.01f, -0.01f, -0.01f), maxbuf(0.01f, 0.01f, 0.01f);
	for (unsigned int i = 1; i < polylist.size(); i++)
	{
		BoundPolygon(pmax, pmin, polylist[i], polygons);
		ExpandBoundingBoxes(Max, Min, pmax);
		ExpandBoundingBoxes(Max, Min, pmin);

	}
		Max = Max + maxbuf;
	Min = Min + minbuf;
}



void MakeDefPoints(BSP_DefPoints& dpnts, std::vector<bsp_vert> &pntslist)
{
	dpnts.head.id = 1;
	dpnts.n_verts = pntslist.size();
	dpnts.n_norms = 0;
	dpnts.offset = 20 + pntslist.size();
	
	dpnts.norm_counts.resize(pntslist.size());
	dpnts.vertex_data.resize(pntslist.size());

	for (unsigned int i = 0; i < pntslist.size(); i++)
	{
		dpnts.norm_counts[i] = (unsigned char)pntslist[i].norms.size();
		dpnts.vertex_data[i].vertex = pntslist[i].point;

		dpnts.vertex_data[i].norms.resize(pntslist[i].norms.size());
		dpnts.n_norms += pntslist[i].norms.size();
		for (unsigned int j = 0; j < pntslist[i].norms.size(); j++)
		{
			dpnts.vertex_data[i].norms[j] = pntslist[i].norms[j];
		}
	}

		dpnts.head.size = dpnts.MySize();
}


void MakeFlatPoly(BSP_FlatPoly &dst, pcs_polygon &src, std::unordered_map<vector3d, int> &norms, std::unordered_map<vector3d, int> &verts, BSP_DefPoints &dpnts)
{
	dst.head.id = 2;
	dst.normal = src.norm;
	dst.nverts = src.verts.size();
	dst.green = dst.blue = dst.pad = 0;
	dst.red = 0xFF;

	dst.verts.resize(dst.nverts);
	std::vector<vector3d> vertices;
	vertices.reserve(dst.nverts);

	for (unsigned int i = 0; i < (unsigned)dst.nverts; i++)
	{
		vertices.push_back(src.verts[i].point);
		dst.verts[i].vertnum = verts[src.verts[i].point];
		dst.verts[i].normnum = norms[src.verts[i].norm];
	}
	dst.center = src.centeroid;

		dst.center = dst.MyCenter(vertices);
	dst.radius = dst.MyRadius(dst.center, vertices);


		dst.head.size = dst.MySize();
}


void MakeTmapPoly(BSP_TmapPoly &dst, pcs_polygon &src, std::unordered_map<vector3d, int> &norms, std::unordered_map<vector3d, int> &verts, BSP_DefPoints &dpnts)
{
	dst.head.id = 3;
	dst.normal = src.norm;
	dst.nverts = src.verts.size();
	dst.tmap_num = src.texture_id;
	std::vector<vector3d> vertices;
	vertices.reserve(dst.nverts);

	dst.verts.resize(dst.nverts);
	for (int i = 0; i < dst.nverts; i++)
	{
		vertices.push_back(src.verts[i].point);
		dst.verts[i].vertnum = verts[src.verts[i].point];
		dst.verts[i].normnum = norms[src.verts[i].norm];
		dst.verts[i].u = src.verts[i].u;
		dst.verts[i].v = src.verts[i].v;
	}

		dst.center = dst.MyCenter(vertices);
	dst.radius = dst.MyRadius(dst.center, vertices);


		dst.head.size = dst.MySize();
}



void BSPTransPMF(unsigned int offset, unsigned char *data, 
		BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
		unsigned int &upolys)
{
	BSP_BlockHeader blkhdr;
	unsigned char *curpos = data + offset;
	
	blkhdr.Read((char *) curpos);

	switch (blkhdr.id)
	{
		case 0: 			break;

		case 1: 			points.Read((char *) curpos + blkhdr.MySize(), blkhdr); 			BSPTransPMF(offset + blkhdr.size, data, points, polygons, upolys); 			break;

		case 2: 			TranslateFPoly(offset, data, points, polygons, upolys); 			break;

		case 3: 			TranslateTPoly(offset, data, points, polygons, upolys); 			break;

		case 4: 			InterpretSortNorm(offset, data, points, polygons, upolys); 			break;
			
		case 5: 			BSPTransPMF(offset + blkhdr.size, data, points, polygons, upolys); 			break;
		default:
			break;
	}

}


void TranslateFPoly(unsigned int offset, unsigned char *data, 
				 BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
				 unsigned int &upolys)
{
	BSP_BlockHeader blkhdr;
	unsigned char *curpos = data + offset;
	blkhdr.Read((char *) curpos);

	vector3d point, norm;
	pcs_polygon temp_poly;

	BSP_FlatPoly fpoly;
	fpoly.Read((char *) curpos + blkhdr.MySize(), blkhdr);

	
	temp_poly.norm = POFTranslate(fpoly.normal);
	temp_poly.texture_id = -1;
	temp_poly.verts.resize(fpoly.nverts);

	
	for (int i = 0; i < fpoly.nverts; i++)
	{
		temp_poly.verts[i].point = POFTranslate(points.vertex_data[fpoly.verts[i].vertnum].vertex);
		temp_poly.verts[i].norm = POFTranslate(points.normals[fpoly.verts[i].normnum]);

		temp_poly.verts[i].u = 0;
		temp_poly.verts[i].v = 0;

	}

	if (upolys >= polygons.size())
	{
		polygons.resize(polygons.size() * 2);
	}
	polygons[upolys] = temp_poly;
	upolys++;

	BSPTransPMF(offset + blkhdr.size, data, points, polygons, upolys); }


void TranslateTPoly(unsigned int offset, unsigned char *data, 
				 BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
				 unsigned int &upolys)
{
	BSP_BlockHeader blkhdr;
	unsigned char *curpos = data + offset;
	blkhdr.Read((char *) curpos);

	vector3d point, norm;

	BSP_TmapPoly tpoly;
	pcs_polygon temp_poly;

	tpoly.Read((char *) curpos + blkhdr.MySize(), blkhdr);
		
	temp_poly.norm = POFTranslate(tpoly.normal);
	temp_poly.texture_id = tpoly.tmap_num;
	temp_poly.verts.resize(tpoly.nverts);
	
	for (int i = 0; i < tpoly.nverts; i++)
	{
		temp_poly.verts[i].point = POFTranslate(points.vertex_data[tpoly.verts[i].vertnum].vertex);
		temp_poly.verts[i].norm = POFTranslate(points.normals[tpoly.verts[i].normnum]);

		temp_poly.verts[i].u = tpoly.verts[i].u;
		temp_poly.verts[i].v = tpoly.verts[i].v;

	}


	if (upolys >= polygons.size())
	{
		polygons.resize(polygons.size() * 2);
	}
	polygons[upolys] = temp_poly;
	upolys++;

	BSPTransPMF(offset + blkhdr.size, data, points, polygons, upolys); }


void InterpretSortNorm(unsigned int offset, unsigned char *data, 
					   BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
						unsigned int &upolys)
{
	BSP_BlockHeader blkhdr;
	BSP_SortNorm snorm;
	unsigned char *curpos = data + offset;
	
	blkhdr.Read((char *) curpos);
	
	snorm.Read((char *) curpos + blkhdr.MySize(), blkhdr);

	if (snorm.front_offset)
		BSPTransPMF(offset + snorm.front_offset, data, points, polygons, upolys); 
	if (snorm.back_offset)
		BSPTransPMF(offset + snorm.back_offset, data, points, polygons, upolys); 
	if (snorm.prelist_offset)
		BSPTransPMF(offset + snorm.prelist_offset, data, points, polygons, upolys); 	
	if (snorm.postlist_offset)
		BSPTransPMF(offset + snorm.postlist_offset, data, points, polygons, upolys); 
	if (snorm.online_offset)
		BSPTransPMF(offset + snorm.online_offset, data, points, polygons, upolys); 

	
	}	



void RenderBSP(unsigned int offset, unsigned char *data, vector3d obj_center)
{
	BSP_BlockHeader blkhdr;
	unsigned char *curpos = data + offset;
	
	blkhdr.Read((char *) curpos);

	switch (blkhdr.id)
	{
		case 0: 			break;

		case 1: 						RenderBSP(offset + blkhdr.size, data, obj_center); 			break;


		case 2: 			RenderUntextured(offset, data, obj_center);
			break;


		case 3: 			RenderTextured(offset, data, obj_center);
			break;

		case 4: 			RenderSortnorm(offset, data, obj_center); 			break;
			
		case 5: 			RenderBBox(offset, data, obj_center); 			break;

		default:
			break;
	}

}


void RenderUntextured(unsigned int offset, unsigned char *data, vector3d obj_center)
{
	BSP_BlockHeader blkhdr;
	unsigned char *curpos = data + offset;
	blkhdr.Read((char *) curpos);

#if defined(__BSP_DEBUG_DRAWNORMS_)
	BSP_FlatPoly fpoly;
	fpoly.Read((char *) curpos + blkhdr.MySize(), blkhdr);

		glColor3f(0.5, 0.5, 1.0);
	vector3d point = POFTranslate(fpoly.center);
	vector3d norm = point+(POFTranslate(fpoly.normal)*5);

	glBegin(GL_POINTS);	
		glVertex3fv((float *)&point);
	glEnd();

	glBegin(GL_LINE_STRIP);	
		glVertex3fv((float *)&point);
		glVertex3fv((float *)&norm);
	glEnd();
		fpoly.Destroy();
#endif
	RenderBSP(offset + blkhdr.size, data, obj_center);
}


void RenderTextured(unsigned int offset, unsigned char *data, vector3d obj_center)
{
	BSP_BlockHeader blkhdr;
	unsigned char *curpos = data + offset;
	blkhdr.Read((char *) curpos);

#if defined(__BSP_DEBUG_DRAWNORMS_)
	BSP_TmapPoly tpoly;
	tpoly.Read((char *) curpos + blkhdr.MySize(), blkhdr);

	
	glColor3f(0.5, 0.5, 1.0);
	vector3d point = POFTranslate(tpoly.center);
	vector3d norm = point+(POFTranslate(tpoly.normal)*5);

	glBegin(GL_POINTS);	
		glVertex3fv((float *)&point);
	glEnd();

	glBegin(GL_LINE_STRIP);	
		glVertex3fv((float *)&point);
		glVertex3fv((float *)&norm);
	glEnd();
		tpoly.Destroy();
#endif
	RenderBSP(offset + blkhdr.size, data, obj_center);
}



void RenderSortnorm(unsigned int offset, unsigned char *data, vector3d obj_center)
{
	BSP_BlockHeader blkhdr;
	BSP_SortNorm snorm;
	unsigned char *curpos = data + offset;
	
	blkhdr.Read((char *) curpos);
	
	snorm.Read((char *) curpos + blkhdr.MySize(), blkhdr);

		glColor3f(1.0, 0.0, 0.0);
	OpenGL_RenderBox(POFTranslate(snorm.min_bounding_box_point), POFTranslate(snorm.max_bounding_box_point));

		if (snorm.front_offset)
		RenderBSP(offset + snorm.front_offset, data, obj_center); 
	if (snorm.back_offset)
		RenderBSP(offset + snorm.back_offset, data, obj_center); 
	if (snorm.prelist_offset)
		RenderBSP(offset + snorm.prelist_offset, data, obj_center); 	
	if (snorm.postlist_offset)
		RenderBSP(offset + snorm.postlist_offset, data, obj_center); 
	if (snorm.online_offset)
		RenderBSP(offset + snorm.online_offset, data, obj_center); 

	
	}


void RenderBBox(unsigned int offset, unsigned char *data, vector3d obj_center)
{
	BSP_BlockHeader blkhdr;
	BSP_BoundBox bbox;
	unsigned char *curpos = data + offset;

	blkhdr.Read((char *) curpos);
	bbox.Read((char *) curpos + blkhdr.MySize(), blkhdr);

	if (blkhdr.id != 5)
		return;
	
	glColor3f(0.0, 1.0, 0.0);
	OpenGL_RenderBox(POFTranslate(bbox.min_point), POFTranslate(bbox.max_point));


		RenderBSP(offset + blkhdr.size, data, obj_center);

}


void OpenGL_RenderBox(vector3d min, vector3d max)
{

	vector3d points[8];
	
	points[0] = vector3d(max.x, max.y, max.z); 
	points[1] = vector3d(max.x, max.y, min.z); 
	points[2] = vector3d(min.x, max.y, min.z); 
	points[3] = vector3d(min.x, max.y, max.z); 
	points[4] = vector3d(max.x, min.y, max.z); 
	points[5] = vector3d(max.x, min.y, min.z); 
	points[6] = vector3d(min.x, min.y, min.z); 
	points[7] = vector3d(min.x, min.y, max.z);

	int polygons[6][4] = {	{ 3, 0, 4, 7 },
							{ 0, 1, 5, 4 },
							{ 0, 1, 2, 3 },
							{ 4, 5, 6, 7 },
							{ 1, 2, 6, 5 },
							{ 2, 3, 7, 6 }};

	for (int i = 0; i < 6; i++)
	{
		glBegin(GL_LINE_STRIP);	
			glVertex3fv((float *)&points[polygons[i][0]]);
			glVertex3fv((float *)&points[polygons[i][1]]);
			glVertex3fv((float *)&points[polygons[i][2]]);
			glVertex3fv((float *)&points[polygons[i][3]]);
			glVertex3fv((float *)&points[polygons[i][0]]);

		glEnd();
	}

}

```

## pcs_pof_bspfuncs.h

```cpp


#if !defined(_pcs_pof_bspfuncs_h_)
#define _pcs_pof_bspfuncs_h_

#include <memory>
#include <unordered_map>

#include "pcs_file.h"
#include "pcs_file_dstructs.h"
#include "POFHandler.h"
#include "BSPDataStructs.h"

vector3d POFTranslate(vector3d v);

struct bsp_vert
{
	vector3d point;
	std::vector<vector3d> norms;
};

bool operator==(const bsp_vert &one, const bsp_vert &two);

bool Neighbor(pcs_shield_triangle &face1, pcs_shield_triangle &face2);

pcs_polygon RebuildCleanPolygon(pcs_polygon &src);

void TriangulateMesh(std::vector<pcs_polygon> &polygons);
void SplitPolygon(std::vector<pcs_polygon> &polygons, int polynum, vector3d plane_point, vector3d plane_normal, std::vector<pcs_polygon> &newpolys);
void SplitIntersecting(std::vector<pcs_polygon> &polygons, vector3d plane_point, vector3d plane_normal);
float FindIntersection(vector3d &intersect, vector3d p1, vector3d p2, vector3d plane_point, vector3d plane_normal);
float DistanceToPlane(vector3d point, vector3d plane_point, vector3d plane_normal);
bool InFrontofPlane(vector3d point, vector3d plane_point, vector3d plane_normal);



enum node_type { SPLIT, POLY, INVALID };

struct bsp_tree_node
{
	bsp_tree_node()
		:Type(INVALID), used(false), counted(false)
	{};
	node_type Type;

		vector3d normal;
	vector3d point;

		std::vector<int> poly_num;

		vector3d bound_min;
	vector3d bound_max;

		std::unique_ptr<bsp_tree_node> front; 	std::unique_ptr<bsp_tree_node> back; 
		bool used;
	bool counted;
};



std::unique_ptr<bsp_tree_node> MakeTree(std::vector<pcs_polygon> &polygons, vector3d &Max, vector3d &Min);
void DebugPrintTree(bsp_tree_node* root, std::ostream &out);

#define BSP_NOERRORS				0

#define BSP_PACK_PREOVERFLOW		0x00000001
#define BSP_PACK_DOUBLEUSE			0x00000002
#define BSP_PACK_UNCOUNTED			0x00000004
#define BSP_PACK_POLYOVERFLOW		0x00000008
#define BSP_PACK_SPLITOVERFLOW		0x00000010
#define BSP_PACK_PREPOLYOVERFLOW	0x00000020
#define BSP_PACK_PRESPLITOVERFLOW	0x00000040

int CalculateTreeSize(bsp_tree_node* root, std::vector<pcs_polygon> &polygons);
int PackTreeInBSP(bsp_tree_node* root, int offset, char *buffer, std::vector<pcs_polygon> &polygons,
	std::unordered_map<vector3d, int> &norms, std::unordered_map<vector3d, int> &verts, BSP_DefPoints &dpnts, vector3d geo_center, int buffsize, int &error_flags);


int CalcSLDCTreeSize(bsp_tree_node* root);
int PackTreeInSLDC(bsp_tree_node* root, int offset, char *buffer, int bufsz);


std::unique_ptr<bsp_tree_node> GenerateTreeRecursion(std::vector<pcs_polygon> &polygons, std::vector<int>&);

bool Bisect(const vector3d& cmax, const vector3d& cmin,
			vector3d &p_point, vector3d &p_norm,
			const std::vector<pcs_polygon>& polygons,
			std::vector<int>& contained,
			std::vector<int>& front,
			std::vector<int>& back,
			vector3d *centera=NULL, vector3d *centerb=NULL);
vector3d PolygonCenter(pcs_polygon &polygon);
void BoundPolygon(vector3d &Max, vector3d &Min, int polygon, std::vector<pcs_polygon> &polygons);
void MakeBound(vector3d &Max, vector3d &Min, std::vector<int> &polylist, std::vector<pcs_polygon> &polygons);

void AddIfNotInList(std::vector<pcs_vertex> &list, pcs_vertex &point);



void MakeTmapPoly(BSP_TmapPoly &dst, pcs_polygon &src, std::unordered_map<vector3d, int> &norms, std::unordered_map<vector3d, int> &verts, BSP_DefPoints &dpnts);
void MakeFlatPoly(BSP_FlatPoly &dst, pcs_polygon &src, std::unordered_map<vector3d, int> &norms, std::unordered_map<vector3d, int> &verts, BSP_DefPoints &dpnts);
void MakeDefPoints(BSP_DefPoints& dpnts, std::vector<bsp_vert> &pntslist);



void BSPTransPMF(unsigned int offset, unsigned char *data, 
		BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
		unsigned int &upolys);

void TranslateFPoly(unsigned int offset, unsigned char *data, 
				 BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
				 unsigned int &upolys);

void TranslateTPoly(unsigned int offset, unsigned char *data, 
				 BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
				 unsigned int &upolys);

void InterpretSortNorm(unsigned int offset, unsigned char *data, 
					   BSP_DefPoints &points, std::vector<pcs_polygon> &polygons,
						unsigned int &upolys);

void RenderBSP(unsigned int offset, unsigned char *data, vector3d obj_center);
void RenderSortnorm(unsigned int offset, unsigned char *data, vector3d obj_center);
void RenderBBox(unsigned int offset, unsigned char *data, vector3d obj_center);
void RenderUntextured(unsigned int offset, unsigned char *data, vector3d obj_center);
void RenderTextured(unsigned int offset, unsigned char *data, vector3d obj_center);
void OpenGL_RenderBox(vector3d min, vector3d max);


#endif 

```

## POFDataStructs.h

```cpp


#include <iostream>


#if !defined(_POF_TYPES_H_)
#define _POF_TYPES_H_
#include "vector3d.h"
#include <string>
#if !defined(uint)
#define uint unsigned int 
#endif


#if !defined(ushort)
#define ushort unsigned short
#endif

#if !defined (ubyte)
#define ubyte unsigned char
#endif

                     








struct Chunk{
	char chunk_id[4];  	int length;  };

 


struct cross_section
{
	float depth, radius;
};

struct muzzle_light
{
	vector3d location;
	int type; };

struct HDR2
{
	float max_radius;           	int obj_flags;                  unsigned int num_subobjects;          
	vector3d min_bounding;           vector3d max_bounding;         
    std::vector<int> sobj_detaillevels;										    std::vector<int> sobj_debris;            								 
    float mass;                    vector3d mass_center;         	float moment_inertia[3][3]; 

   
	std::vector<cross_section> cross_sections; 
	std::vector<muzzle_light> lights;			HDR2() : max_radius(0), obj_flags(0), num_subobjects(0), mass(0) {
		memset(moment_inertia, 0, sizeof(moment_inertia));
	}
};



struct TXTR
{
  std::vector<std::string> tex_filename;    };

struct PINF
{
	std::vector<char> strings; };


struct path_vert
{
	vector3d pos;
	float radius;
	std::vector<int> sobj_number; };

struct a_path {
	std::string name;
	std::string parent;
	std::vector<path_vert> verts; };

struct PATH
{
	std::vector<a_path> paths; };

struct special_point
{
	std::string name;
    std::string properties;
	vector3d point;
    float radius;
};


struct SPCL
{
	std::vector<special_point> special_points; 
};


struct shield_face
{                     
	vector3d face_normal;
    int face_vertices[3];        int neighbors[3];        
};

struct SHLD
{
	std::vector<vector3d> vertecies; 	std::vector<shield_face> shield_faces;
};



struct SLDC_node_head {
     char type;      unsigned int size; };

struct SLDC_node_split {
    SLDC_node_head header;     vector3d bound_min;     vector3d bound_max;     unsigned int front_offset;     unsigned int back_offset; };


struct SLDC_node_leaf {
    SLDC_node_head header;     vector3d bound_min;     vector3d bound_max;     unsigned int num_polygons;     };

struct SLDC
{
	  std::vector<char> tree_data;
	  SLDC() {}
};


struct  eye_pos
{
	int sobj_number;      	vector3d sobj_offset;   	vector3d normal;
};
struct EYE
{
	std::vector<eye_pos> eye_positions;
};


struct gun
{
	vector3d point;
	vector3d norm;
};

struct slot
{
	std::vector<gun> guns;                   
  
};

struct GPNT_MPNT
{
	std::vector<slot> slots;
};



struct Turret_bank
{
	int sobj_parent;     int sobj_par_phys;     
    vector3d turret_normal;
	std::vector<vector3d> position; 

};

struct TGUN_TMIS {
	std::vector<Turret_bank> banks;
};


struct dock_point
{
	std::string properties; 
	std::vector<int> path_number;

	std::vector<gun> points;
};


struct DOCK
{
	std::vector<dock_point> points;
};



struct glow_point
{
	vector3d pos;
    vector3d norm;       float radius;
};

struct thruster
{
                      
			std::string properties;
	                      
	std::vector<glow_point> points;
};

struct FUEL
{
	std::vector<thruster> thrusters;
};




struct OBJ2
{
	int submodel_number;  
	
	float radius;        	int submodel_parent; 	vector3d offset;       
	vector3d geometric_center;
	vector3d bounding_box_min_point;
	vector3d bounding_box_max_point;
	
		std::string submodel_name;
	std::string properties;
	int movement_type;
    int movement_axis;

	    int reserved;         	std::vector<char> bsp_data; 								  		OBJ2() : submodel_number(0), radius(0.0), submodel_parent(-1), movement_type(-1), movement_axis(-1), reserved(0) {}
	~OBJ2() {}
};




struct insg_face_point
{
	int vertex_index;     float u_texture_coordinate;
    float v_texture_coordinate;
};

struct insg_face
{
	insg_face_point points[3];
};

struct insig
{

	int detail_level; 	std::vector<vector3d> vertex_pos; 
	vector3d offset; 
	std::vector<insg_face> faces; };


struct INSG
{
	std::vector<insig> insignias;
};




struct ACEN
{
	vector3d point;
};




struct HullLightPoint 
{ 
	vector3d point; 
	vector3d norm; 
	float radius; 
}; 

struct HullLights  
{ 
	int disp_time;
	int on_time; 
	int off_time; 
	int obj_parent;  
	int LOD; 
	int type; 
	std::string properties;
	std::vector<HullLightPoint> lights;
	HullLights() : disp_time(0), on_time(0), off_time(0), obj_parent(0), LOD(0), type(0), lights(0) {}
}; 

struct GLOW 
{ 
	std::vector<HullLights> lights; 
}; 

#endif 
```

## POFHandler.cpp

```cpp


#if !defined(_WIN32)
#include "compat/filelength.h"
#include "compat/strncmp.h"
#endif

#include <memory.h>
#include <cstdint>
#include <cstring>
#include <string>
#include <boost/scoped_array.hpp>

#include "POFHandler.h"








template<typename T>
void write_to_file(std::ostream& out, const T& value) {
	out.write(reinterpret_cast<const char*>(&value), sizeof(T));
}

template<>
void write_to_file(std::ostream& out, const std::string& value) {
	out.write(value.c_str(), value.size());
}

template<>
void write_to_file(std::ostream& out, const std::vector<char>& value) {
	out.write(value.data(), value.size());
}

void write_to_file(std::ostream& out, const char* value) {
	out.write(value, strlen(value));
}

template<>
void write_to_file(std::ostream& out, const uint64_t& value);
template<>
void write_to_file(std::ostream& out, const int64_t& value);


void POF::SLDC_SetTree(const std::vector<char>& sldc_tree)
{
	shield_collision.tree_data = sldc_tree;
}

void POF::SLDC_SetTree(std::vector<char>&& sldc_tree)
{
	shield_collision.tree_data.swap(sldc_tree);
}




void POF::StatsToFile(std::ofstream &outfile)
{
	unsigned int i;
	vector3d vect;

	vect = ACEN_Get_acen();

		outfile << "ACEN: (" << vect.x << "," << vect.y << "," << vect.z << ")" << std::endl;


		outfile << "DOCK: " << DOCK_Count_Docks() << " docks." << std::endl;
	
	for (i = 0; i < DOCK_Count_Docks(); i++)
	{
		outfile << "    +Dock[" << i << "]: " << DOCK_Count_Points(i) << " points, " << DOCK_Count_SplinePaths(i) << " spline paths." << std::endl;
	}


		outfile << " EYE: " << EYE_Count_Eyes() << " eyes." << std::endl;


		outfile << "FUEL: " << FUEL_Count_Thrusters() << " thrusters." << std::endl;

	for (i = 0; i < FUEL_Count_Thrusters(); i++)
	{
		outfile << "    +Fuel[" << i << "]: " << FUEL_Count_Glows(i) << " glow points." << std::endl;
	}

		outfile << "GPNT: " << GPNT_SlotCount() << " slots." << std::endl;

	for (i = 0; i < GPNT_SlotCount(); i++)
	{
		outfile << "    +Gun[" << i << "]: " << GPNT_PointCount(i) << " firing points." << std::endl;
	}


		outfile << "MPNT: " << MPNT_SlotCount() << " slots." << std::endl;

	for (i = 0; i < MPNT_SlotCount(); i++)
	{
		outfile << "    +Mis[" << i << "]: " << MPNT_PointCount(i) << " firing points." << std::endl;
	}

		outfile << "HRD2: " << HDR2_Get_Mass() << " object mass, " << HDR2_Get_SOBJCount() << " SubObjects." << std::endl;

		outfile << "INSG: " << INSG_Count_Insignia() << " insignias." << std::endl;

		outfile << "OBJ2: " << OBJ2_Count() << " SubObjects." << std::endl;

	for (i = 0; i < OBJ2_Count(); i++)
	{
		outfile << "    +sobj[" << i << "]:" << OBJ2_BSP_Datasize(i) << " bytes of BSP data." << std::endl;
	}

		outfile << "PATH: " << PATH_Count_Paths() << " paths." << std::endl;

	for (i = 0; i < PATH_Count_Paths(); i++)
	{
		outfile << "    +Path[" << i << "]: " << PATH_Count_Verts(i) << " verts. Parent: " << StringToAPS(paths.paths[i].parent) << ", Name: " << StringToAPS(paths.paths[i].name) << std::endl;
	}

	
	outfile << "PINF: ";
	
	std::vector<std::string> strings = PINF_Get();
	for (i = 0; i < strings.size(); i++)
	{
		outfile << strings[i].c_str() << ", ";
	}

	outfile << std::endl;

		outfile << "SHLD: " << SHLD_Count_Faces() << " faces, " << SHLD_Count_Vertices() << " verts." << std::endl;

		outfile << "SPCL: " << SPCL_Count() << " specials." << std::endl;

		outfile << "TGUN: " << TGUN_Count_Banks() << " turrets." << std::endl;

		outfile << "TMIS: " << TMIS_Count_Banks() << " turrets." << std::endl;

		outfile << "TXTR: " << TXTR_Count_Textures() << " textures." << std::endl;

	for (i = 0; i < TXTR_Count_Textures(); i++)
	{
		outfile << "    +tex[" << i << "]: " << TXTR_GetTextures(i) << std::endl;
	}


}



std::string Parse_BPOFstring(char *&localptr)
{
	std::string retval;
	int len;

	memcpy(&len, localptr, sizeof(int));
	localptr += sizeof(int);

	boost::scoped_array<char> str(new char[len+1]);
	
	memcpy(str.get(), localptr, len);
	localptr += len;

	str[len] = '\0';
	
	retval = str.get();
	return retval;

}


void POF::Parse_Memory_PNT(int mode, char *buffer)
{
		char *localptr = buffer;
	GPNT_MPNT *pnt = PNT_Alias(mode);

	unsigned int num_slots;
	memcpy(&num_slots, buffer, 4);
	localptr += 4;

	pnt->slots.resize(num_slots);
	

	for (unsigned int i = 0; i < num_slots; i++)
	{
		unsigned int num_guns;
		memcpy(&num_guns, localptr, 4);
		pnt->slots[i].guns.resize(num_guns);
		localptr += 4; 
		for (unsigned int j = 0; j < num_guns; j++)
		{
			memcpy(&pnt->slots[i].guns[j], localptr, sizeof(gun));
			localptr += sizeof(gun);
		}
	}
}


void POF::Parse_Memory_T(int mode, char *buffer)
{
	TGUN_TMIS *pnt = T_Alias(mode);

	char *localptr = buffer;

	unsigned int num_banks;
	memcpy(&num_banks, localptr, 4);
	localptr += 4;

	pnt->banks.resize(num_banks);

	for (unsigned int i = 0; i < num_banks; i++)
	{
				memcpy(&pnt->banks[i].sobj_parent, localptr, 4);
		localptr += 4; 
				memcpy(&pnt->banks[i].sobj_par_phys, localptr, 4);
		localptr += 4; 
				memcpy(&pnt->banks[i].turret_normal, localptr, 12);
		localptr += 12; 
				unsigned int num_firing_points;
		memcpy(&num_firing_points, localptr, 4);
		localptr += 4; 
		pnt->banks[i].position.resize(num_firing_points);

		for (unsigned int j = 0; j < num_firing_points; j++)
		{
						memcpy(&pnt->banks[i].position[j], localptr, 12);
			localptr += 12;
		}

	}

}


void POF::Parse_Memory_OBJ2(char *buffer)
{

	OBJ2 temp;
	char *localptr = buffer;

	memcpy(&temp.submodel_number, localptr, sizeof(int));
	localptr += sizeof(int);

	memcpy(&temp.radius, localptr, sizeof(float));
	localptr += sizeof(float);

	memcpy(&temp.submodel_parent, localptr, sizeof(int));
	localptr += sizeof(int);

	memcpy(&temp.offset, localptr, sizeof(vector3d));
	localptr += sizeof(vector3d);

	memcpy(&temp.geometric_center, localptr, sizeof(vector3d));
	localptr += sizeof(vector3d);

	memcpy(&temp.bounding_box_min_point, localptr, sizeof(vector3d));
	localptr += sizeof(vector3d);

	memcpy(&temp.bounding_box_max_point, localptr, sizeof(vector3d));
	localptr += sizeof(vector3d);

		
	temp.submodel_name = Parse_BPOFstring(localptr);

		
	temp.properties = Parse_BPOFstring(localptr);

	memcpy(&temp.movement_type, localptr, sizeof(int));
	localptr += sizeof(int);

	memcpy(&temp.movement_axis, localptr, sizeof(int));
	localptr += sizeof(int);

	memcpy(&temp.reserved, localptr, sizeof(int));
	localptr += sizeof(int);

	int size = temp.bsp_data.size();
	memcpy(&size, localptr, sizeof(int));
	localptr += sizeof(int);

	temp.bsp_data.resize(size);

	memcpy(&temp.bsp_data.front(), localptr, temp.bsp_data.size());
	
		temp.reserved = 0;
	objects.push_back(temp);
}


void POF::Parse_Memory_DOCK(char *buffer)
{
	char *localptr = buffer;

	unsigned int num_docks;
	memcpy(&num_docks, localptr, sizeof(int));
	localptr += sizeof(int);

	docking.points.resize(num_docks);

	for (unsigned int i = 0; i < num_docks; i++)
	{
				
		docking.points[i].properties = Parse_BPOFstring(localptr);

		unsigned int num_spline_paths;
		memcpy(&num_spline_paths, localptr, sizeof(int));
		localptr += sizeof(int);

		docking.points[i].path_number.resize(num_spline_paths);

		for (unsigned int j = 0; j < num_spline_paths; j++)
		{
			memcpy(&docking.points[i].path_number[j], localptr, sizeof(int));
			localptr += sizeof(int);
		}

		unsigned int num_points;
		memcpy(&num_points, localptr, sizeof(int));
		localptr += sizeof(int);

		docking.points[i].points.resize(num_points);

		for (unsigned int k = 0; k < num_points; k++)
		{
			memcpy(&docking.points[i].points[k], localptr, sizeof(gun));
			localptr += sizeof(gun);
		}
	}
}


void POF::Parse_Memory_GLOW(char *buffer)
{
		char *localptr = buffer;

	unsigned int num_glows_arrays;
	memcpy(&num_glows_arrays, localptr, sizeof(int));
	localptr += sizeof(int);

	hull_lights.lights.resize(num_glows_arrays);

	for (unsigned int i = 0; i < num_glows_arrays; i++)
	{
		memcpy(&hull_lights.lights[i].disp_time, localptr, sizeof(int));
		localptr += sizeof(int);

		memcpy(&hull_lights.lights[i].on_time, localptr, sizeof(int));
		localptr += sizeof(int);

		memcpy(&hull_lights.lights[i].off_time, localptr, sizeof(int));
		localptr += sizeof(int);

		memcpy(&hull_lights.lights[i].obj_parent, localptr, sizeof(int));
		localptr += sizeof(int);

		memcpy(&hull_lights.lights[i].LOD, localptr, sizeof(int));
		localptr += sizeof(int);

		memcpy(&hull_lights.lights[i].type, localptr, sizeof(int));
		localptr += sizeof(int);
		
		unsigned int num_Lights;
		memcpy(&num_Lights, localptr, sizeof(int));
		localptr += sizeof(int);

		
		hull_lights.lights[i].properties = Parse_BPOFstring(localptr);

		hull_lights.lights[i].lights.resize(num_Lights);

		for (unsigned int j = 0; j < num_Lights; j++)
		{
			memcpy(&hull_lights.lights[i].lights[j].point, localptr, sizeof(vector3d));
			localptr += sizeof(vector3d);

			memcpy(&hull_lights.lights[i].lights[j].norm, localptr, sizeof(vector3d));
			localptr += sizeof(vector3d);

			memcpy(&hull_lights.lights[i].lights[j].radius, localptr, sizeof(float));
			localptr += sizeof(float);
		
		}
	}
}


void POF::Parse_Memory_FUEL(char *buffer)
{
	char *localptr = buffer;

	unsigned int num_thrusters;
	memcpy(&num_thrusters, localptr, sizeof(int));
	localptr += sizeof(int);

	thrusters.thrusters.resize(num_thrusters);

	for (unsigned int i = 0; i < num_thrusters; i++)
	{
		unsigned int num_glows;
		memcpy(&num_glows, localptr, sizeof(int));
		localptr += sizeof(int);

				if (version >= 2117)
		{
						thrusters.thrusters[i].properties = Parse_BPOFstring(localptr);
		}
										
		thrusters.thrusters[i].points.resize(num_glows);

		for (unsigned int j = 0; j < num_glows; j++)
		{
			memcpy(&thrusters.thrusters[i].points[j], localptr, sizeof(glow_point));
			localptr += sizeof(glow_point);
		}

	}
}


void POF::Parse_Memory_SHLD(char *buffer)
{
	char *localptr = buffer;

	unsigned int num_vertices;
	memcpy(&num_vertices, localptr, sizeof(int));
	localptr += sizeof(int);

	shields.vertecies.resize(num_vertices);

	for (unsigned int i = 0; i < num_vertices; i++)
	{
		memcpy(&shields.vertecies[i], localptr, sizeof(vector3d));
		localptr += sizeof(vector3d);
	}

	unsigned int num_faces;
	memcpy(&num_faces, localptr, sizeof(int));
	localptr += sizeof(int);

	shields.shield_faces.resize(num_faces);

	for (unsigned int j = 0; j < num_faces; j++)
	{
		memcpy(&shields.shield_faces[j], localptr, sizeof(shield_face));
		localptr += sizeof(shield_face);
	}


}


void POF::Parse_Memory_EYE(char *buffer)
{
	char *localptr = buffer;

	unsigned int num_eye_positions;
	memcpy(&num_eye_positions, localptr, sizeof(int));
	localptr += sizeof(int);
	
	eyes.eye_positions.resize(num_eye_positions);
	
	for (unsigned int i = 0; i < num_eye_positions; i++)
	{
		memcpy(&eyes.eye_positions[i], localptr, sizeof(eye_pos));
		localptr += sizeof(eye_pos);
	}
}


void POF::Parse_Memory_ACEN(char *buffer)
{ 	memcpy(&autocentering.point, buffer, sizeof(vector3d));
}


void POF::Parse_Memory_INSG(char *buffer)
{
	char *localptr = buffer;

	unsigned int num_insignias;
	memcpy(&num_insignias, localptr, sizeof(int));
	localptr += sizeof(int);

	insignia.insignias.resize(num_insignias);

	for (unsigned int i = 0; i < num_insignias; i++)
	{
		memcpy(&insignia.insignias[i].detail_level, localptr, sizeof(int));
		localptr += sizeof(int);

		unsigned int num_faces;
		memcpy(&num_faces, localptr, sizeof(int));
		localptr += sizeof(int);
		
		unsigned int num_verticies;
		memcpy(&num_verticies, localptr, sizeof(int));
		localptr += sizeof(int);

		insignia.insignias[i].vertex_pos.resize(num_verticies);
		insignia.insignias[i].faces.resize(num_faces);

		for (unsigned int j = 0; j < num_verticies; j++)
		{
			memcpy(&insignia.insignias[i].vertex_pos[j], localptr, sizeof(vector3d));
			localptr += sizeof(vector3d);
		}

		memcpy(&insignia.insignias[i].offset, localptr, sizeof(vector3d));
		localptr += sizeof(vector3d);

		for (unsigned int k = 0; k < num_faces; k++)
		{
			memcpy(&insignia.insignias[i].faces[k], localptr, sizeof(insg_face));
			localptr += sizeof(insg_face);
		}
	

	}

}


void POF::Parse_Memory_PATH(char *buffer)
{
	char *localptr = buffer;

	unsigned int num_paths;
	memcpy(&num_paths, localptr, sizeof(int));
	localptr += sizeof(int);

	paths.paths.resize(num_paths);

	for (unsigned int i = 0; i < num_paths; i++)
	{
				paths.paths[i].name = Parse_BPOFstring(localptr);

				paths.paths[i].parent = Parse_BPOFstring(localptr);

		unsigned int num_verts;
		memcpy(&num_verts, localptr, sizeof(int));
		localptr += sizeof(int);

		paths.paths[i].verts.resize(num_verts);

		for (unsigned int j = 0; j < num_verts; j++)
		{
			memcpy(&paths.paths[i].verts[j].pos, localptr, sizeof(vector3d));
			localptr += sizeof(vector3d);

			memcpy(&paths.paths[i].verts[j].radius, localptr, sizeof(float));
			localptr += sizeof(float);

			unsigned int num_turrets;
			memcpy(&num_turrets, localptr, sizeof(int));
			localptr += sizeof(int);
			
			paths.paths[i].verts[j].sobj_number.resize(num_turrets);

			for (unsigned int k = 0; k < num_turrets; k++)
			{
				memcpy(&paths.paths[i].verts[j].sobj_number[k], localptr, sizeof(int));
				localptr += sizeof(int);
			}
		}


	}
	
}


void POF::Parse_Memory_SLDC(char *buffer)
{
	char *localptr = buffer;

	int size;
	memcpy(&size, localptr, sizeof(unsigned int));
	localptr += sizeof(unsigned int);

	shield_collision.tree_data.resize(size);
	memcpy(&shield_collision.tree_data.front(), localptr, size);
}

void POF::Parse_Memory_PINF (char *buffer, int size)
{
	pofinfo.strings.resize(size);
	if (size) {
		memcpy(&pofinfo.strings.front(), buffer, size);
	}

}

void POF::Parse_Memory_SPCL(char *buffer)
{
		char *localptr = buffer;

	unsigned int num_special_points;
	memcpy(&num_special_points, localptr, sizeof(int));
	localptr += sizeof(int);

	specials.special_points.resize(num_special_points);

	for (unsigned int i = 0; i < num_special_points; i++)
	{
				specials.special_points[i].name = Parse_BPOFstring(localptr);

				specials.special_points[i].properties = Parse_BPOFstring(localptr);

		memcpy(&specials.special_points[i].point, localptr, sizeof(vector3d));
		localptr += sizeof(vector3d);

		memcpy(&specials.special_points[i].radius, localptr, sizeof(float));
		localptr += sizeof(float);
	}
}



void POF::Parse_Memory_HDR2(char *buffer)
{
	unsigned int i, first = sizeof(float) + (2 * sizeof(int)) + (2 * sizeof(vector3d));
	char *localptr = buffer;
			memcpy(&header, localptr, first);
	localptr += first;

	unsigned int num_detaillevels;
	memcpy(&num_detaillevels, localptr, sizeof(int));
	localptr += sizeof(int);

	header.sobj_detaillevels.resize(num_detaillevels);

	for (i = 0; i < num_detaillevels; i++)
	{
		memcpy(&header.sobj_detaillevels[i], localptr, sizeof(int));
		localptr += sizeof(int);
	}
	
	unsigned int num_debris;
	memcpy(&num_debris, localptr, sizeof(int));
	localptr += sizeof(int);

	header.sobj_debris.resize(num_debris);

	for (i = 0; i < num_debris; i++)
	{
		memcpy(&header.sobj_debris[i], localptr, sizeof(int));
		localptr += sizeof(int);
	}
	
	memcpy(&header.mass, localptr, sizeof(float));
	localptr += sizeof(float);

	memcpy(&header.mass_center, localptr, sizeof(vector3d));
	localptr += sizeof(vector3d);

	memcpy(header.moment_inertia, localptr, sizeof(float) * 9);
	localptr += (sizeof(float) * 9);

	int num_cross_sections;
	memcpy(&num_cross_sections, localptr, sizeof(int));
	localptr += sizeof(int);

		if (num_cross_sections == -1)
		num_cross_sections = 0;

	header.cross_sections.resize(num_cross_sections);

	for (i = 0; i < (unsigned int)num_cross_sections; i++)
	{
		memcpy(&header.cross_sections[i], localptr, sizeof(cross_section));
		localptr += sizeof(cross_section);
	}

	unsigned int num_lights;
	memcpy(&num_lights, localptr, sizeof(int));
	localptr += sizeof(int);

	header.lights.resize(num_lights);

	for (i = 0; i < num_lights; i++)
	{
		memcpy(&header.lights[i], localptr, sizeof(muzzle_light));
		localptr += sizeof(muzzle_light);
	}
}


void POF::Parse_Memory_TXTR(char *buffer)
{
		char *localptr = buffer;

	unsigned int num_textures;
	memcpy(&num_textures, localptr, sizeof(int));
	localptr += sizeof(int);

	textures.tex_filename.resize(num_textures);

	for (unsigned int i = 0; i < num_textures; i++)
	{
				textures.tex_filename[i] = Parse_BPOFstring(localptr);
	}
}


int POF::LoadPOF(std::ifstream &infile)
{
	char main_buffer[5], secondary_buffer[5];
	boost::scoped_array<char> dynamic_buffer;
	int len;
	std::string sig("PSPO");

	memset(main_buffer, 0, 5);
	memset(secondary_buffer, 0, 5);
	
	infile.read(main_buffer, 4);

	if (std::string(main_buffer) != sig)
	{
		return -1;
	}

	infile.read(main_buffer, 4);
	memcpy(&version, main_buffer, 4);

	if (version < 2116)
	{
		return -2;
	}

	while (1) 	{
		memset(main_buffer, 0, 5);
		memset(secondary_buffer, 0, 5);
		
		if(!infile.read(main_buffer, 4))
			break; 
				infile.read(secondary_buffer, 4);
		memcpy(&len, secondary_buffer, 4);

		dynamic_buffer.reset(new char[len]);
		infile.read(dynamic_buffer.get(), len);

		if (!_strnicmp(main_buffer, "TXTR", 4))
			Parse_Memory_TXTR(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "HDR2", 4))
			Parse_Memory_HDR2(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "OBJ2", 4))
			Parse_Memory_OBJ2(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "SPCL", 4))
			Parse_Memory_SPCL(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "GPNT", 4))
			Parse_Memory_GPNT(dynamic_buffer.get());
		
		else if (!_strnicmp(main_buffer, "MPNT", 4))
			Parse_Memory_MPNT(dynamic_buffer.get());
		
		else if (!_strnicmp(main_buffer, "TGUN", 4))
			Parse_Memory_TGUN(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "TMIS", 4))
			Parse_Memory_TMIS(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "DOCK", 4))
			Parse_Memory_DOCK(dynamic_buffer.get());
		
		else if (!_strnicmp(main_buffer, "FUEL", 4))
			Parse_Memory_FUEL(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "SHLD", 4))
			Parse_Memory_SHLD(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "EYE ", 4))
			Parse_Memory_EYE(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "ACEN", 4))
			Parse_Memory_ACEN(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "INSG", 4))
			Parse_Memory_INSG(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "PATH", 4))
			Parse_Memory_PATH(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "GLOW", 4))
			Parse_Memory_GLOW(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "SLDC", 4))
			Parse_Memory_SLDC(dynamic_buffer.get());

		else if (!_strnicmp(main_buffer, "PINF ", 4))
			Parse_Memory_PINF (dynamic_buffer.get(), len);

			}

		version = 2117;

	return 0;
}

bool POF::SavePOF(std::ofstream &outfile) {
	unsigned int size, i, j, k, itemp;
	OBJ2 *local_sobj;
	
		write_to_file(outfile, "PSPO");

		write_to_file(outfile, version);

		if (textures.tex_filename.size() > 0)
	{
		write_to_file(outfile, "TXTR");
		
				size = 4 + (textures.tex_filename.size() * 4);
		for (i = 0; i < textures.tex_filename.size(); i++)
		{
			size += textures.tex_filename[i].length();
		}

		write_to_file(outfile, size);

				write_to_file(outfile, (int)textures.tex_filename.size());

		for (i = 0; i < textures.tex_filename.size(); i++)
		{
						itemp = textures.tex_filename[i].length();
			write_to_file(outfile, itemp);

						write_to_file(outfile, textures.tex_filename[i]);
		}

	}

			write_to_file(outfile, "HDR2");

		size = 104; 	size += (header.sobj_detaillevels.size() * 4);
	size += (header.sobj_debris.size() * 4);
	size += (header.cross_sections.size() * sizeof(cross_section));
	size += (header.lights.size() * sizeof(muzzle_light));
	
	write_to_file(outfile, size);

		write_to_file(outfile, header.max_radius); 

	write_to_file(outfile, header.obj_flags); 

	write_to_file(outfile, header.num_subobjects); 

	write_to_file(outfile, header.min_bounding); 

	write_to_file(outfile, header.max_bounding); 

	


	write_to_file(outfile, (int)header.sobj_detaillevels.size()); 

		for (i = 0; i < header.sobj_detaillevels.size(); i++)
	{
		write_to_file(outfile, header.sobj_detaillevels[i]); 
	}

	
	
	write_to_file(outfile, (int)header.sobj_debris.size()); 

		for (i = 0; i < header.sobj_debris.size(); i++)
	{
		write_to_file(outfile, header.sobj_debris[i]); 
	}

	

	write_to_file(outfile, header.mass); 

	write_to_file(outfile, header.mass_center); 

	write_to_file(outfile, header.moment_inertia); 

	
	write_to_file(outfile, (int)header.cross_sections.size()); 

		for (i = 0; i < header.cross_sections.size(); i++)
	{
		write_to_file(outfile, header.cross_sections[i]); 
	}

	
	
	write_to_file(outfile, (int)header.lights.size()); 

		for (i = 0; i < header.lights.size(); i++)
	{
		write_to_file(outfile, header.lights[i]); 
	}

		for (i = 0; i < OBJ2_Count(); i++)
	{
		local_sobj = &objects[i];
				write_to_file(outfile, "OBJ2");
		
				size = 84 + local_sobj->submodel_name.length() + local_sobj->properties.length() + local_sobj->bsp_data.size();
		
		write_to_file(outfile, size);

		write_to_file(outfile, local_sobj->submodel_number); 

		write_to_file(outfile, local_sobj->radius); 

		write_to_file(outfile, local_sobj->submodel_parent); 

		write_to_file(outfile, local_sobj->offset); 

		write_to_file(outfile, local_sobj->geometric_center); 

		write_to_file(outfile, local_sobj->bounding_box_min_point); 

		write_to_file(outfile, local_sobj->bounding_box_max_point); 

		itemp = local_sobj->submodel_name.length();
		write_to_file(outfile, itemp); 

		write_to_file(outfile, local_sobj->submodel_name);

		itemp = local_sobj->properties.length();
		write_to_file(outfile, itemp); 

		write_to_file(outfile, local_sobj->properties);

		write_to_file(outfile, local_sobj->movement_type); 

		write_to_file(outfile, local_sobj->movement_axis); 

		write_to_file(outfile, static_cast<int>(local_sobj->reserved)); 

		write_to_file(outfile, static_cast<int>(local_sobj->bsp_data.size()));

		write_to_file(outfile, local_sobj->bsp_data);
	}

		if (SPCL_Count() > 0)
	{
				write_to_file(outfile, "SPCL");
		
				size = 4;
		for (i = 0; i < SPCL_Count(); i++)
		{
			size += 24 + specials.special_points[i].name.length() + specials.special_points[i].properties.length();
		}
		
		write_to_file(outfile, size);
		
		write_to_file(outfile, (int)specials.special_points.size()); 
	
		for (i = 0; i < SPCL_Count(); i++)
		{
			itemp = specials.special_points[i].name.length();
			write_to_file(outfile, itemp); 
			write_to_file(outfile, specials.special_points[i].name);	

			itemp = specials.special_points[i].properties.length();
			write_to_file(outfile, itemp); 
			write_to_file(outfile, specials.special_points[i].properties);	

			write_to_file(outfile, specials.special_points[i].point); 
			
			write_to_file(outfile, specials.special_points[i].radius); 

		}

	}

		if (GPNT_SlotCount() > 0)
	{


				write_to_file(outfile, "GPNT");
		
				size = 4 + (4 * GPNT_SlotCount());


		for (i = 0; i < GPNT_SlotCount(); i++)
		{
			size += PNT_Alias(0)->slots[i].guns.size() * sizeof(gun);
		}

		write_to_file(outfile, size);

		write_to_file(outfile, (int)PNT_Alias(0)->slots.size()); 

		for (i = 0; i < GPNT_SlotCount(); i++)
		{
			write_to_file(outfile, (int)PNT_Alias(0)->slots[i].guns.size()); 

			for (j = 0; j < PNT_Alias(0)->slots[i].guns.size(); j++)
			{
				write_to_file(outfile, PNT_Alias(0)->slots[i].guns[j].point); 

				write_to_file(outfile, PNT_Alias(0)->slots[i].guns[j].norm); 

			}

		}
	}

		if (MPNT_SlotCount() > 0)
	{


				write_to_file(outfile, "MPNT");
		
				size = 4 + (4 * MPNT_SlotCount());


		for (i = 0; i < MPNT_SlotCount(); i++)
		{
			size += PNT_Alias(1)->slots[i].guns.size() * sizeof(gun);
		}
		
		write_to_file(outfile, size);

		write_to_file(outfile, (int)PNT_Alias(1)->slots.size()); 

		for (i = 0; i < MPNT_SlotCount(); i++)
		{
			write_to_file(outfile, (int)PNT_Alias(1)->slots[i].guns.size()); 

			for (j = 0; j < PNT_Alias(1)->slots[i].guns.size(); j++)
			{
				write_to_file(outfile, PNT_Alias(1)->slots[i].guns[j].point); 

				write_to_file(outfile, PNT_Alias(1)->slots[i].guns[j].norm); 

			}

		}
	}

		if (T_Alias(0)->banks.size() > 0)
	{
				write_to_file(outfile, "TGUN");
		
				size = 4 + (24 * T_Alias(0)->banks.size());


		for (i = 0; i < T_Alias(0)->banks.size(); i++)
		{
			size += (T_Alias(0)->banks[i].position.size() * 12);
		}
		
		write_to_file(outfile, size);

		write_to_file(outfile, (int)T_Alias(0)->banks.size()); 

		for (i = 0; i < T_Alias(0)->banks.size(); i++)
		{

			write_to_file(outfile, T_Alias(0)->banks[i].sobj_parent); 

			write_to_file(outfile, T_Alias(0)->banks[i].sobj_par_phys); 

			write_to_file(outfile, T_Alias(0)->banks[i].turret_normal); 

			write_to_file(outfile, (int)T_Alias(0)->banks[i].position.size()); 

			for (j = 0; j < T_Alias(0)->banks[i].position.size(); j++)
			{
					write_to_file(outfile, T_Alias(0)->banks[i].position[j]); 
			}
		}

	}

		if (T_Alias(1)->banks.size() > 0)
	{
				write_to_file(outfile, "TMIS");
		
				size = 4 + (24 * T_Alias(1)->banks.size());


		for (i = 0; i < T_Alias(1)->banks.size(); i++)
		{
			size += (T_Alias(1)->banks[i].position.size() * 12);
		}
		
		write_to_file(outfile, size);

		write_to_file(outfile, (int)T_Alias(1)->banks.size()); 

		for (i = 0; i < T_Alias(1)->banks.size(); i++)
		{

			write_to_file(outfile, T_Alias(1)->banks[i].sobj_parent); 

			write_to_file(outfile, T_Alias(1)->banks[i].sobj_par_phys); 

			write_to_file(outfile, T_Alias(1)->banks[i].turret_normal); 

			write_to_file(outfile, (int)T_Alias(1)->banks[i].position.size()); 

			for (j = 0; j < T_Alias(1)->banks[i].position.size(); j++)
			{
					write_to_file(outfile, T_Alias(1)->banks[i].position[j]); 
			}
		}

	}

		if (docking.points.size() > 0)
	{
		write_to_file(outfile, "DOCK");

		size = 4;

		for (i = 0; i < docking.points.size(); i++)
		{
			size += 4;
			size += docking.points[i].properties.length();
			size += 4;
			size += (4 * docking.points[i].path_number.size());
			size += 4;
			size += (sizeof(gun) * docking.points[i].points.size());
		}


		write_to_file(outfile, size); 

		write_to_file(outfile, (int)docking.points.size()); 

		for (i = 0; i < docking.points.size(); i++)
		{
			itemp = docking.points[i].properties.length();
			write_to_file(outfile, itemp); 
			write_to_file(outfile, docking.points[i].properties);

			write_to_file(outfile, (int)docking.points[i].path_number.size()); 

			for (j = 0; j < docking.points[i].path_number.size(); j++)
			{
				write_to_file(outfile, docking.points[i].path_number[j]); 
			}

			write_to_file(outfile, (int)docking.points[i].points.size()); 

			for (k = 0; k < docking.points[i].points.size(); k++)
			{
				write_to_file(outfile, docking.points[i].points[k].point); 

				write_to_file(outfile, docking.points[i].points[k].norm); 
			}


		}
	}

		if (FUEL_Count_Thrusters() > 0)
	{
		write_to_file(outfile, "FUEL");

		size = 4 + (8 * FUEL_Count_Thrusters());

		for (i = 0; i < FUEL_Count_Thrusters(); i++)
		{
			size += (thrusters.thrusters[i].properties.length() + (sizeof(glow_point) * thrusters.thrusters[i].points.size()));
		}

		write_to_file(outfile, size); 

		write_to_file(outfile, (int)thrusters.thrusters.size()); 

		for (i = 0; i < FUEL_Count_Thrusters(); i++)
		{
			write_to_file(outfile, (int)thrusters.thrusters[i].points.size()); 

			itemp = thrusters.thrusters[i].properties.length();
			write_to_file(outfile, itemp); 
			write_to_file(outfile, thrusters.thrusters[i].properties);

			for (j = 0; j < FUEL_Count_Glows(i); j++)
			{
				write_to_file(outfile, thrusters.thrusters[i].points[j]); 

			}

			

		}
	}

		if (shields.shield_faces.size() > 0 || shields.vertecies.size() > 0)
	{
		write_to_file(outfile, "SHLD");

		size = 8 + (sizeof(vector3d) * shields.vertecies.size()) + (sizeof(shield_face) * shields.shield_faces.size());

		write_to_file(outfile, size); 

		write_to_file(outfile, (int)shields.vertecies.size()); 

		for (i = 0; i < shields.vertecies.size(); i++)
		{
			write_to_file(outfile, shields.vertecies[i]); 
		}

		write_to_file(outfile, (int)shields.shield_faces.size()); 


		for (i = 0; i < shields.shield_faces.size(); i++)
		{
			write_to_file(outfile, shields.shield_faces[i]); 
		}
	}

		if (eyes.eye_positions.size() > 0)
	{
		outfile.write("EYE ", 4);

		size = 4 + (sizeof(eye_pos) * eyes.eye_positions.size());

		write_to_file(outfile, size); 

		write_to_file(outfile, (int)eyes.eye_positions.size()); 

		for (i = 0; i < eyes.eye_positions.size(); i++)
		{
			write_to_file(outfile, eyes.eye_positions[i]); 
		}
	}
		if (ACEN_IsSet())
	{
		write_to_file(outfile, "ACEN");
		k = 12;
		
		write_to_file(outfile, k); 

		write_to_file(outfile, autocentering.point); 

	}

		if (insignia.insignias.size() > 0)
	{

		write_to_file(outfile, "INSG");

		size = 4; 
		for (i = 0; i < insignia.insignias.size(); i++)
		{
			size += 24; 			size += (sizeof(vector3d) * insignia.insignias[i].vertex_pos.size());
			size += (sizeof(insg_face) * insignia.insignias[i].faces.size());
		}

		write_to_file(outfile, size); 

		write_to_file(outfile, (int)insignia.insignias.size()); 

		for (i = 0; i < insignia.insignias.size(); i++)
		{
			write_to_file(outfile, insignia.insignias[i].detail_level); 

			write_to_file(outfile, (int)insignia.insignias[i].faces.size()); 
	
			write_to_file(outfile, (int)insignia.insignias[i].vertex_pos.size()); 
			
			for (j = 0; j < insignia.insignias[i].vertex_pos.size(); j++)
			{
				write_to_file(outfile, insignia.insignias[i].vertex_pos[j]); 
			}

			write_to_file(outfile, insignia.insignias[i].offset); 

			for (j = 0; j < insignia.insignias[i].faces.size(); j++)
			{
				write_to_file(outfile, insignia.insignias[i].faces[j]);
			}
		}
	}

		if (paths.paths.size() > 0)
	{

		write_to_file(outfile, "PATH");

		size = 4;

		for (i = 0; i < paths.paths.size(); i++)
		{
			size += (paths.paths[i].name.length() + paths.paths[i].parent.length());
			size += 8; 			size += 4; 
			for (j = 0; j < paths.paths[i].verts.size(); j++)
			{
								size += 12;
								size += 4;
								size += 4;
								size += (4 * paths.paths[i].verts[j].sobj_number.size());
			}


		}


		write_to_file(outfile, size); 
		outfile.flush();

		write_to_file(outfile, (int)paths.paths.size()); 
		outfile.flush();

		for (i = 0; i < paths.paths.size(); i++)
		{
			itemp = paths.paths[i].name.length();
			write_to_file(outfile, itemp); 
			outfile.flush();

			write_to_file(outfile, paths.paths[i].name);
			outfile.flush();

			itemp = paths.paths[i].parent.length();
			write_to_file(outfile, itemp); 
			outfile.flush();

			write_to_file(outfile, paths.paths[i].parent);
			outfile.flush();

			write_to_file(outfile, (int)paths.paths[i].verts.size()); 

			for (j = 0; j < paths.paths[i].verts.size(); j++)
			{
				write_to_file(outfile, paths.paths[i].verts[j].pos); 

				write_to_file(outfile, paths.paths[i].verts[j].radius); 
			
				write_to_file(outfile, (int)paths.paths[i].verts[j].sobj_number.size()); 

				for (k = 0; k < paths.paths[i].verts[j].sobj_number.size(); k++)
				{
					write_to_file(outfile, paths.paths[i].verts[j].sobj_number[k]); 
				}
			
			}


		}

	}
		if (hull_lights.lights.size() != 0)
	{

				write_to_file(outfile, "GLOW");
		k = 4 + (8 * sizeof(int)) * hull_lights.lights.size(); 																 		for ( i  = 0; i < hull_lights.lights.size(); i++)
		{
			k += hull_lights.lights[i].properties.length();
			k += sizeof(HullLightPoint) * hull_lights.lights[i].lights.size();
		}

				write_to_file(outfile, k); 

				
		write_to_file(outfile, (int)hull_lights.lights.size());
		outfile.flush();


		for (auto& light : hull_lights.lights)
		{
			write_to_file(outfile, light.disp_time);
			outfile.flush();

			write_to_file(outfile, light.on_time);
			outfile.flush();

			write_to_file(outfile, light.off_time);
			outfile.flush();

			write_to_file(outfile, light.obj_parent);
			outfile.flush();

			write_to_file(outfile, light.LOD);
			outfile.flush();

			write_to_file(outfile, light.type);
			outfile.flush();
			
			write_to_file(outfile, (int)light.lights.size());
			outfile.flush();

			itemp = light.properties.length();
			write_to_file(outfile, itemp);
			outfile.flush();


			write_to_file(outfile, light.properties);
			outfile.flush();


			for (auto& l : light.lights)
			{
				write_to_file(outfile, l.point);
				outfile.flush();

				write_to_file(outfile, l.norm);
				outfile.flush();

				write_to_file(outfile, l.radius);
				outfile.flush();
			
			}
		}
	}

		if (!shield_collision.tree_data.empty())
	{
		write_to_file(outfile, "SLDC");
		int tree_size = shield_collision.tree_data.size();
		k = sizeof(int) + tree_size;

		write_to_file(outfile, k); 
		write_to_file(outfile, tree_size);
		write_to_file(outfile, shield_collision.tree_data);
	}

		if (!pofinfo.strings.empty())
	{
				write_to_file(outfile, "PINF");

		write_to_file(outfile, (int)pofinfo.strings.size()); 
		write_to_file(outfile, pofinfo.strings);
	}
	
	return true;
}


void POF::ClearAllData()
{
	version = 2117;
	objects.clear();

	textures.tex_filename.clear();
	header = HDR2();
	specials.special_points.clear();
	gunpoints.slots.clear();
	missilepoints.slots.clear();
	turretguns.banks.clear();
	turretmissiles.banks.clear();
	docking.points.clear();
	thrusters.thrusters.clear();
	shields.vertecies.clear();
	shields.shield_faces.clear();
	eyes.eye_positions.clear();
	autocentering.point = vector3d();
	insignia.insignias.clear();
	paths.paths.clear();
	pofinfo.strings.clear();
	hull_lights.lights.clear();
	shield_collision = SLDC();

}




GPNT_MPNT* POF::PNT_Alias(int mode) {
			if (mode == 1)
		return &missilepoints;
	return &gunpoints;
}


void POF::PNT_AddSlot				(int mode)
{


	PNT_Alias(mode)->slots.push_back(slot());
}



bool POF::PNT_AddPoint				(int mode, int slot, vector3d point, vector3d norm)
{
	if ((unsigned)slot > PNT_SlotCount(mode))
		return false;

	gun newgun;

	newgun.norm = norm;
	newgun.point = point;
	PNT_Alias(mode)->slots[slot].guns.push_back(newgun);
	return true;
}


unsigned int  POF::PNT_SlotCount				(int mode)
{
	
	return PNT_Alias(mode)->slots.size();
}


unsigned int  POF::PNT_PointCount				(int mode, int slot)
{

	if ((unsigned)slot > PNT_Alias(mode)->slots.size())
		return -1; 
	return PNT_Alias(mode)->slots[slot].guns.size();

}



bool POF::PNT_DelSlot				(int mode, int slot_num)
{
	if ((unsigned)slot_num > PNT_Alias(mode)->slots.size())
		return false;
	PNT_Alias(mode)->slots.erase(PNT_Alias(mode)->slots.begin() + slot_num);
	return true;

}

bool POF::PNT_DelPoint				(int mode, int slot, int point)
{
	if ((unsigned)slot > PNT_Alias(mode)->slots.size())
		return false;

	if ((unsigned)point > PNT_Alias(mode)->slots[slot].guns.size())
		return false;

	PNT_Alias(mode)->slots[slot].guns.erase(PNT_Alias(mode)->slots[slot].guns.begin() + point);
	return true;

}



bool POF::PNT_EditPoint				(int mode, int slot, int point_num, vector3d point, vector3d norm)
{
	if ((unsigned)slot > PNT_Alias(mode)->slots.size())
		return false;

	if ((unsigned)point_num > PNT_Alias(mode)->slots[slot].guns.size())
		return false;

	PNT_Alias(mode)->slots[slot].guns[point_num].point = point;
	PNT_Alias(mode)->slots[slot].guns[point_num].norm = norm;

	return true;

}


bool POF::PNT_GetPoint				(int mode, int slot, int point_num, vector3d &point, vector3d &norm)
{
	if ((unsigned)slot > PNT_Alias(mode)->slots.size())
		return false;

	if ((unsigned)point_num > PNT_Alias(mode)->slots[slot].guns.size())
		return false;

	point = PNT_Alias(mode)->slots[slot].guns[point_num].point;
	norm = PNT_Alias(mode)->slots[slot].guns[point_num].norm;

	return true;
}



TGUN_TMIS* POF::T_Alias(int mode) {
			if (mode == 1)
		return &turretmissiles;
	return &turretguns;
}

void POF::T_Add_Bank					(int mode, int sobj_parent, int sobj_par_phys, vector3d normal)
{
	Turret_bank nbank;
	nbank.sobj_par_phys = sobj_par_phys;
	nbank.sobj_parent = sobj_parent;
	nbank.turret_normal = normal;
	T_Alias(mode)->banks.push_back(nbank);
}


bool POF::T_Add_FirePoint			(int mode, int bank, vector3d pos)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return false;
	T_Alias(mode)->banks[bank].position.push_back(pos);
	return true;
}





bool POF::T_Edit_Bank				(int mode, int bank, int sobj_parent, int sobj_par_phys, vector3d normal)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return false;

	T_Alias(mode)->banks[bank].sobj_par_phys = sobj_par_phys;
	T_Alias(mode)->banks[bank].sobj_parent = sobj_parent;
	T_Alias(mode)->banks[bank].turret_normal = normal;

	return true;
}


bool POF::T_Edit_FirePoint			(int mode, int bank, int point, vector3d pos)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return false;

	if ((unsigned)point > T_Count_Points(mode, bank))
		return false;

	T_Alias(mode)->banks[bank].position[point] = pos;

	return true;

}


bool POF::T_Del_FirePoint			(int mode, int bank, int point)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return false;

	if ((unsigned)point > T_Count_Points(mode, bank))
		return false;
	T_Alias(mode)->banks[bank].position.erase(T_Alias(mode)->banks[bank].position.begin() + point);
	return true;
}


bool POF::T_Del_Bank					(int mode, int bank)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return false;
	T_Alias(mode)->banks.erase(T_Alias(mode)->banks.begin() + bank);
	return true;
}



unsigned int POF::T_Count_Banks				(int mode)
{
	return T_Alias(mode)->banks.size();
}


unsigned int POF::T_Count_Points				(int mode, int bank)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return -1;
	return T_Alias(mode)->banks[bank].position.size();
}


bool POF::T_Get_Bank				(int mode, int bank, int &sobj_parent, int &sobj_par_phys, vector3d &normal)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return false;

	sobj_parent = T_Alias(mode)->banks[bank].sobj_parent;
	sobj_par_phys = T_Alias(mode)->banks[bank].sobj_par_phys;
	normal = T_Alias(mode)->banks[bank].turret_normal;

	return true;
}


bool POF::T_Get_FirePoint			(int mode, int bank, int point, vector3d &pos)
{
	if ((unsigned)bank > T_Count_Banks(mode))
		return false;

	if ((unsigned)point > T_Count_Points(mode, bank))
		return false;

	pos = T_Alias(mode)->banks[bank].position[point];
	

	return true;
}



int POF::TXTR_AddTexture(std::string texname)
{	
	textures.tex_filename.push_back(APStoString(texname));
	return 0;
}


bool POF::TXTR_DelTexture(int texture)
{
	textures.tex_filename.erase(textures.tex_filename.begin() + texture);
	return true;

}


int POF::TXTR_FindTexture(std::string texname)
{
	
	for (unsigned int i = 0; i < textures.tex_filename.size(); i++)
	{
		
		
		
						if (texname == textures.tex_filename[i])
			return i;

			}

	return -1;
}

bool POF::TXTR_Edit_Texture(int texture, std::string textname)
{
	if (texture < 0 || (unsigned)texture > textures.tex_filename.size())
		return false;

	textures.tex_filename[texture] = APStoString(textname);
	return true;
}


std::string POF::TXTR_GetTextures(int texture)
{
	if (texture < 0 || (unsigned)texture > textures.tex_filename.size())
		return std::string("Error: Invalid Index");
	
	return StringToAPS(textures.tex_filename[texture]);

}





void POF::HDR2_Get_Details				(int &num, std::vector<int> &SOBJ_nums)
{
	num = header.sobj_detaillevels.size();
	SOBJ_nums = header.sobj_detaillevels;
}


void POF::HDR2_Set_Details				(int num, std::vector<int> SOBJ_nums)
{
	header.sobj_detaillevels = SOBJ_nums;
}


void POF::HDR2_Get_Debris				(int &num, std::vector<int> &SOBJ_nums)
{
	num = header.sobj_debris.size();
	SOBJ_nums = header.sobj_debris;
}

void POF::HDR2_Set_Debris				(int num, std::vector<int> SOBJ_nums)
{
	header.sobj_debris = SOBJ_nums;
}


void POF::HDR2_Get_MomentInertia			(float inertia[3][3])
{
	for (int i = 0; i < 3; i++)
		for (int j = 0; j < 3; j++)
			inertia[i][j] = header.moment_inertia[i][j];
}

void POF::HDR2_Set_MomentInertia			(float inertia[3][3])
{
	for (int i = 0; i < 3; i++)
		for (int j = 0; j < 3; j++)
			header.moment_inertia[i][j] = inertia[i][j];

}


void POF::HDR2_Get_CrossSections		(int &num, std::vector<cross_section> &sections)
{
	num = header.cross_sections.size();
	sections = header.cross_sections;
}

void POF::HDR2_Set_CrossSections		(int num, std::vector<cross_section> sections)
{
	header.cross_sections = sections;
}


void POF::HDR2_Get_Lights				(int &num, std::vector<muzzle_light> &li)
{
	num = header.lights.size();
	li = header.lights;
}

void POF::HDR2_Set_Lights				(int num, const std::vector<muzzle_light> &li)
{
	header.lights = li;
}


int  POF::OBJ2_Add						(OBJ2 &obj)
{
	int i = OBJ2_Add_SOBJ();
	objects[i] = obj;

	return i;
}


int  POF::OBJ2_Add_SOBJ					()
{
	objects.push_back(OBJ2());
	return objects.size() - 1;
}


bool POF::OBJ2_Del_SOBJ					(int SOBJNum)
{
	objects.erase(objects.begin() + SOBJNum);
	return true;
}


unsigned int POF::OBJ2_Count()
{
	return objects.size();
}


bool POF::OBJ2_Set_SOBJNum				(int SOBJNum, int num)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].submodel_number = num;

	return true;
}

bool POF::OBJ2_Get_SOBJNum				(int SOBJNum, int &num)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	num = objects[SOBJNum].submodel_number;

	return true;
}


bool POF::OBJ2_Set_Radius				(int SOBJNum, float rad)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].radius = rad;

	return true;
}

bool POF::OBJ2_Get_Radius				(int SOBJNum, float &rad)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	rad = objects[SOBJNum].radius;

	return true;
}


bool POF::OBJ2_Set_Parent				(int SOBJNum, int parent)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].submodel_parent = parent;

	return true;
}


bool POF::OBJ2_Get_Parent				(int SOBJNum, int &parent)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	parent = objects[SOBJNum].submodel_parent;

	return true;
}


bool POF::OBJ2_Set_Offset				(int SOBJNum, vector3d offset)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].offset = offset;

	return true;
}


bool POF::OBJ2_Get_Offset				(int SOBJNum, vector3d &offset)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	offset = objects[SOBJNum].offset;

	return true;
}


bool POF::OBJ2_Set_GeoCenter			(int SOBJNum, vector3d GeoCent)
{
	
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].geometric_center = GeoCent;

	return true;

}

bool POF::OBJ2_Get_GeoCenter			(int SOBJNum, vector3d &GeoCent)
{
	
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	GeoCent = objects[SOBJNum].geometric_center;

	return true;

}


bool POF::OBJ2_Set_BoundingMin			(int SOBJNum, vector3d min)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].bounding_box_min_point = min;

	return true;
}


bool POF::OBJ2_Get_BoundingMin			(int SOBJNum, vector3d &min)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	min = objects[SOBJNum].bounding_box_min_point;

	return true;
}


bool POF::OBJ2_Set_BoundingMax			(int SOBJNum, vector3d max)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].bounding_box_max_point = max;

	return true;
}

bool POF::OBJ2_Get_BoundingMax			(int SOBJNum, vector3d &max)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	max = objects[SOBJNum].bounding_box_max_point;

	return true;
}


bool POF::OBJ2_Set_Name					(int SOBJNum, std::string name)
{

	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].submodel_name = APStoString(name);

	return true;
}

bool POF::OBJ2_Get_Name					(int SOBJNum, std::string &name)
{

	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	name = StringToAPS(objects[SOBJNum].submodel_name);

	return true;
}


bool POF::OBJ2_Set_Props					(int SOBJNum, std::string properties)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].properties = APStoString(properties);

	return true;
}

bool POF::OBJ2_Get_Props					(int SOBJNum, std::string &properties)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	properties = StringToAPS(objects[SOBJNum].properties);

	return true;
}


bool POF::OBJ2_Set_MoveType				(int SOBJNum, int type)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return false;
	objects[SOBJNum].movement_type = type;

	return true;
}

bool POF::OBJ2_Get_MoveType				(int SOBJNum, int &type)
{
	if ((unsigned)SOBJNum > OBJ2_Count() || SOBJNum < 0)
		return false;
	type = objects[SOBJNum].movement_type;

	return true;
}


bool POF::OBJ2_Set_MoveAxis				(int SOBJNum, int axis)
{
	if ((unsigned)SOBJNum > OBJ2_Count() || SOBJNum < 0)
		return false;
	objects[SOBJNum].movement_axis = axis;

	return true;
}

bool POF::OBJ2_Get_MoveAxis				(int SOBJNum, int &axis)
{
	if ((unsigned)SOBJNum > OBJ2_Count() || SOBJNum < 0)
		return false;
	axis = objects[SOBJNum].movement_axis;

	return true;
}


unsigned int POF::OBJ2_BSP_Datasize(int SOBJNum)
{
	if ((unsigned)SOBJNum > OBJ2_Count())
		return -1;
	return objects[SOBJNum].bsp_data.size();

}


bool POF::OBJ2_Get_BSPDataPtr			(int SOBJNum, int &size, char* &bsp_data)
{
	if ((unsigned)SOBJNum > OBJ2_Count() || SOBJNum < 0)
		return false;
	size = OBJ2_BSP_Datasize(SOBJNum);

	if (size == 0)
	{
		bsp_data = NULL;
		return true;
	}

	bsp_data = &objects[SOBJNum].bsp_data.front();

	return true;
}

bool POF::OBJ2_Get_BSPData				(int SOBJNum, std::vector<char> &bsp_data)
{
	if ((unsigned)SOBJNum > OBJ2_Count() || SOBJNum < 0)
		return false;
	int size = OBJ2_BSP_Datasize(SOBJNum);

	if (size == 0)
	{
		bsp_data.clear();
		return true;
	}
	bsp_data = objects[SOBJNum].bsp_data;

	return true;
}




void POF::SPCL_AddSpecial				(std::string Name, std::string Properties, vector3d point, float radius)
{
	special_point npoint;
	npoint.name = APStoString(Name);
	npoint.point = point;
	npoint.properties = APStoString(Properties);
	npoint.radius = radius;
	specials.special_points.push_back(npoint);
}


bool POF::SPCL_DelSpecial				(int num)
{
	if ((unsigned)num > SPCL_Count())
		return false;
	specials.special_points.erase(specials.special_points.begin() + num);
	return true;
}


unsigned int  POF::SPCL_Count					()
{
	return specials.special_points.size();
}


bool POF::SPCL_Get_Special				(int num, std::string &Name, std::string &Properties, vector3d &point, float &radius)
{
	if ((unsigned)num > SPCL_Count())
		return false;

	Name = StringToAPS(specials.special_points[num].name);
	Properties = StringToAPS(specials.special_points[num].properties);
	point = specials.special_points[num].point;
	radius = specials.special_points[num].radius;
	return true;
}


bool POF::SPCL_Edit_Special				(int num, std::string Name, std::string Properties, vector3d point, float radius)
{
	
	if ((unsigned)num > SPCL_Count())
		return false;
	
	specials.special_points[num].name = APStoString(Name);
	specials.special_points[num].properties = APStoString(Properties);
	specials.special_points[num].point = point;
	specials.special_points[num].radius = radius;

	return true;
}




void POF::DOCK_Add_Dock				(std::string properties)
{
	dock_point npt;
	npt.properties = APStoString(properties);
	docking.points.push_back(npt);
}

bool POF::DOCK_Add_SplinePath		(int dock, int path)
{
	if (dock < 0  || (unsigned)dock > DOCK_Count_Docks())
		return false;
	docking.points[dock].path_number.push_back(path);
	return true;
}

bool POF::DOCK_Add_Point			(int dock, vector3d point, vector3d norm)
{
	if (dock < 0  || (unsigned)dock > DOCK_Count_Docks())
		return false;
	gun np;
	np.norm = norm;
	np.point = point;
	docking.points[dock].points.push_back(np);
	return true;
}


unsigned int POF::DOCK_Count_Docks			()
{
	return docking.points.size();
}

unsigned int POF::DOCK_Count_SplinePaths		(int dock)
{
	if (dock < 0  || (unsigned)dock > docking.points.size())
		return -1;
	return docking.points[dock].path_number.size();
}

unsigned int POF::DOCK_Count_Points			(int dock)
{
	if (dock < 0  || (unsigned)dock > docking.points.size())
		return -1;
	return docking.points[dock].points.size();
}


bool POF::DOCK_Get_SplinePath		(int dock, int spline_path_num, int &path)
{
	if (dock < 0  || spline_path_num < 0 || (unsigned)dock > DOCK_Count_Docks() || (unsigned)spline_path_num > DOCK_Count_SplinePaths(dock))
		return false;

	path = docking.points[dock].path_number[spline_path_num];
	return true;
}


bool POF::DOCK_Get_Point			(int dock, int point, vector3d &pnt, vector3d &norm)
{
	if (dock < 0  || point < 0 || (unsigned)dock > DOCK_Count_Docks() || (unsigned)point > DOCK_Count_Points(dock))
		return false;

	norm = docking.points[dock].points[point].norm;
	pnt = docking.points[dock].points[point].point;
	return true;
}

bool POF::DOCK_Get_DockProps		(int dock, std::string &properties)
{
{
	if (dock < 0  || (unsigned)dock > DOCK_Count_Docks())
		return false;

	properties = StringToAPS(docking.points[dock].properties);

	return true;
}
}


bool POF::DOCK_Edit_SplinePath		(int dock, int spline_path_num, int path)
{
	if (dock < 0  || spline_path_num < 0 || (unsigned)dock > DOCK_Count_Docks() || (unsigned)spline_path_num > DOCK_Count_SplinePaths(dock))
		return false;

	docking.points[dock].path_number[spline_path_num] = path;
	return true;
}

bool POF::DOCK_Edit_Point			(int dock, int point, vector3d pnt, vector3d norm)
{
	if (dock < 0  || point < 0 || (unsigned)dock > DOCK_Count_Docks() || (unsigned)point > DOCK_Count_Points(dock))
		return false;

	docking.points[dock].points[point].norm = norm;
	docking.points[dock].points[point].point = pnt;
	return true;
}


bool POF::DOCK_Edit_DockProps		(int dock, std::string properties)
{
	if (dock < 0  || (unsigned)dock > DOCK_Count_Docks())
		return false;

	docking.points[dock].properties = APStoString(properties);

	return true;
}


bool POF::DOCK_Del_Dock				(int dock)
{
	if (dock < 0  || (unsigned)dock > DOCK_Count_Docks())
		return false;
	docking.points.erase(docking.points.begin() + dock);
	return true;

}

bool POF::DOCK_Del_SplinePath		(int dock, int spline_path_num)
{
	if (dock < 0  || (unsigned)dock > DOCK_Count_Docks() || (unsigned)spline_path_num > DOCK_Count_SplinePaths(dock))
		return false;
	docking.points[dock].path_number.erase(docking.points[dock].path_number.begin() + spline_path_num);
	return true;
}

bool POF::DOCK_Del_Point			(int dock, int point)
{
	if (dock < 0  || (unsigned)dock > DOCK_Count_Docks() || (unsigned)point > DOCK_Count_Points(dock))
		return false;
	docking.points[dock].points.erase(docking.points[dock].points.begin() + point);
	return true;

}


void POF::FUEL_Add_Thruster			(std::string properties)
{
	thruster n;
	n.properties = APStoString(properties);
	thrusters.thrusters.push_back(n);
}

bool POF::FUEL_Add_GlowPoint		(int bank, float radius, vector3d pos, vector3d norm)
{
	if ((unsigned)bank > FUEL_Count_Thrusters())
		return false;
		glow_point ng;
	ng.norm = norm;
	ng.pos = pos;
	ng.radius = radius;
	thrusters.thrusters[bank].points.push_back(ng);
	return true;	
}


unsigned int POF::FUEL_Count_Thrusters		()
{ return thrusters.thrusters.size(); }

unsigned int POF::FUEL_Count_Glows			(int thruster)
{ 
	if ((unsigned)thruster > FUEL_Count_Thrusters())
		return -1;
	return thrusters.thrusters[thruster].points.size();
}


bool POF::FUEL_Edit_GlowPoint		(int thruster, int gp, float radius, vector3d pos, vector3d norm)
{
	if ((unsigned)thruster > FUEL_Count_Thrusters() || (unsigned)gp > FUEL_Count_Glows(thruster))
		return false;

	thrusters.thrusters[thruster].points[gp].radius = radius;
	thrusters.thrusters[thruster].points[gp].pos = pos ;
	thrusters.thrusters[thruster].points[gp].norm = norm;

	return true;
}

bool POF::FUEL_Edit_ThrusterProps	(int thruster, std::string properties)
{
	if ((unsigned)thruster > FUEL_Count_Thrusters())
		return false;
	thrusters.thrusters[thruster].properties = APStoString(properties);

	return true;
}



bool POF::FUEL_Del_Thruster			(int thrust)
{
	if ((unsigned)thrust > FUEL_Count_Thrusters())
		return false;
	thrusters.thrusters.erase(thrusters.thrusters.begin() + thrust);
	return true;

}


bool POF::FUEL_Del_GlowPoint			(int thruster, int glowpoint)
{
	if ((unsigned)thruster > FUEL_Count_Thrusters() || (unsigned)glowpoint > FUEL_Count_Glows(thruster))
		return false;
	thrusters.thrusters[thruster].points.erase(thrusters.thrusters[thruster].points.begin() + glowpoint);
	return true;
}


bool POF::FUEL_Get_GlowPoint			(int thruster, int gp, float &radius, vector3d &pos, vector3d &norm)
{
	if ((unsigned)thruster > FUEL_Count_Thrusters() || (unsigned)gp > FUEL_Count_Glows(thruster))
		return false;

	radius = thrusters.thrusters[thruster].points[gp].radius;
	pos = thrusters.thrusters[thruster].points[gp].pos;
	norm = thrusters.thrusters[thruster].points[gp].norm;

	return true;
}

bool POF::FUEL_Get_ThrusterProps		(int thruster, std::string &properties)
{
	if ((unsigned)thruster > FUEL_Count_Thrusters())
		return false;
	properties = StringToAPS(thrusters.thrusters[thruster].properties);

	return true;
}



void POF::SHLD_Add_Vertex			(vector3d vert)
{
	shields.vertecies.push_back(vert);
}

void POF::SHLD_Add_Face				(vector3d normal, const int fcs[3], const int nbs[3])
{
	shield_face nface;

	nface.face_normal = normal;

	for (int i = 0; i < 3; i++)
	{
		nface.face_vertices[i] = fcs[i];
		nface.neighbors[i] = nbs[i];
	}
	shields.shield_faces.push_back(nface);
}
								
unsigned int POF::SHLD_Count_Vertices		()
{
	return shields.vertecies.size();
}

unsigned int POF::SHLD_Count_Faces			()
{
	return shields.shield_faces.size();
}


bool POF::SHLD_Get_Face				(int face, vector3d &normal, int fcs[3], int nbs[3])
{
	if ((unsigned)face > SHLD_Count_Faces())
		return false;
	normal = shields.shield_faces[face].face_normal;

	for (int i = 0; i < 3; i++)
	{
		fcs[i] = shields.shield_faces[face].face_vertices[i];
		nbs[i] = shields.shield_faces[face].neighbors[i];
	}

	return true;
}

bool POF::SHLD_Get_Vertex			(int vertex, vector3d &vert)
{
	if ((unsigned)vertex > SHLD_Count_Vertices())
		return false;
	vert = shields.vertecies[vertex];

	return true;
}


bool POF::SHLD_Edit_Vertex			(int vertex, vector3d &vert)
{
	if ((unsigned)vertex > SHLD_Count_Vertices())
		return false;
	shields.vertecies[vertex] = vert;

	return true;
}


bool POF::SHLD_Edit_Face			(int face, vector3d normal, const int fcs[3], const int nbs[3])
{
	if ((unsigned)face > SHLD_Count_Faces())
		return false;
	shields.shield_faces[face].face_normal = normal;

	for (int i = 0; i < 3; i++)
	{
		shields.shield_faces[face].face_vertices[i] = fcs[i] ;
		shields.shield_faces[face].neighbors[i] = nbs[i];
	}
	
	return true;
}


bool POF::SHLD_Del_Vertex			(int vertex)
{
	if ((unsigned)vertex > SHLD_Count_Vertices())
		return false;
	shields.vertecies.erase(shields.vertecies.begin() + vertex);
	return true;
}

bool POF::SHLD_Del_Face				(int face)
{
	if ((unsigned)face > SHLD_Count_Faces())
		return false;
	shields.shield_faces.erase(shields.shield_faces.begin() + face);
	return true;
}

void POF::EYE_Add_Eye				(int sobj_num, vector3d offset, vector3d normal)
{
	eye_pos eye_temp;
	eye_temp.normal = normal;
	eye_temp.sobj_number = sobj_num;
	eye_temp.sobj_offset = offset;
	eyes.eye_positions.push_back(eye_temp);
}


bool POF::EYE_Del_Eye				(int eye)
{
	if (eye >= (int)eyes.eye_positions.size())
		return false;
	eyes.eye_positions.erase(eyes.eye_positions.begin() + eye);
	return true;
}

unsigned int POF::EYE_Count_Eyes			()
{
	return eyes.eye_positions.size();
}

bool POF::EYE_Get_Eye				(int eye, int &sobj_num, vector3d &offset, vector3d &normal)
{
	if ((unsigned)eye > eyes.eye_positions.size())
		return false;

	sobj_num = eyes.eye_positions[eye].sobj_number;
	offset = eyes.eye_positions[eye].sobj_offset;
	normal = eyes.eye_positions[eye].normal;

	return true;
}

bool POF::EYE_Edit_Eye				(int eye, int sobj_num, vector3d offset, vector3d normal)
{
	if ((unsigned)eye > eyes.eye_positions.size())
		return false;

	eyes.eye_positions[eye].normal = normal;
	eyes.eye_positions[eye].sobj_number = sobj_num;
	eyes.eye_positions[eye].sobj_offset = offset;

	return true;
}


bool POF::ACEN_IsSet					()
{
	vector3d temp;
	temp.x = 0;
	temp.y = 0;
	temp.z = 0;
	return !(ACEN_Get_acen() == temp);
}


void POF::ACEN_Set_acen				(vector3d point)
{
	autocentering.point = point;
}

bool POF::ACEN_Del_acen				()
{
	

	autocentering.point.x = 0;
	autocentering.point.y = 0;
	autocentering.point.z = 0;

	return true;
}

vector3d POF::ACEN_Get_acen			()
{
	return autocentering.point;
}



void POF::INSG_Add_insignia			(int lod, vector3d offset)
{
			insig ni;
		ni.detail_level = lod;
	ni.offset = offset;
	insignia.insignias.push_back(ni);
}

bool POF::INSG_Add_Insig_Vertex		(int insig, vector3d vertex)
{
		if ((unsigned)insig > INSG_Count_Insignia())
		return false;
	insignia.insignias[insig].vertex_pos.push_back(vertex);
	return true;
}

bool POF::INSG_Add_Insig_Face		(int insig, const int vert_indecies[], const vector3d u_tex_coord, const vector3d v_tex_coord)
{
		if ((unsigned)insig > INSG_Count_Insignia())
		return false;
	
	insg_face nf;
	
	float a[3], b[3];
	int i;
			memcpy((char *) a, (char *) &u_tex_coord, sizeof(vector3d)); 	memcpy((char *) b, (char *) &v_tex_coord, sizeof(vector3d));	

	for (i = 0; i < 3; i++)
	{
		nf.points[i].vertex_index = vert_indecies[i];
		nf.points[i].u_texture_coordinate = a[i];
		nf.points[i].v_texture_coordinate = b[i];
	}
	insignia.insignias[insig].faces.push_back(nf);
	return true;
}


bool POF::INSG_Add_Insig_Face		(int insig, insg_face &InsgFace)
{
	if ((unsigned)insig > INSG_Count_Insignia())
		return false;
	insignia.insignias[insig].faces.push_back(InsgFace);
	return true;
}


unsigned int POF::INSG_Count_Insignia		()
{ return insignia.insignias.size(); }

unsigned int POF::INSG_Count_Vertecies		(int insig)
{
	if ((unsigned)insig > INSG_Count_Insignia())
		return -1;
	return insignia.insignias[insig].vertex_pos.size();
}

unsigned int POF::INSG_Count_Faces			(int insig)
{
	if ((unsigned)insig > INSG_Count_Insignia())
		return -1;
	return insignia.insignias[insig].faces.size();
}



bool POF::INSG_Get_Insignia			(int insig, int &lod, vector3d &offset)
{
	if ((unsigned)insig > INSG_Count_Insignia())
		return false;
	lod = insignia.insignias[insig].detail_level;
	offset = insignia.insignias[insig].offset;

	return true;
}

int  POF::INST_Find_Vert				(int insig, vector3d vertex)
{
	if ((unsigned)insig > INSG_Count_Insignia())
		return -1;	

	for (unsigned int i = 0; i < insignia.insignias[insig].vertex_pos.size(); i++)
	{
		if (insignia.insignias[insig].vertex_pos[i] == vertex)
			return i;
	}
	return -1;	
}

bool POF::INSG_Get_Insig_Vertex		(int insig, int vert, vector3d &vertex)
{
	if ((unsigned)insig > INSG_Count_Insignia() || (unsigned)vert > INSG_Count_Vertecies(insig))
		return false;

	vertex = insignia.insignias[insig].vertex_pos[vert];
	return true;
}


bool POF::INSG_Get_Insig_Face		(int insig, int face, int vert_indecies[], vector3d &u_tex_coord, vector3d &v_tex_coord)
{
	if ((unsigned)insig > INSG_Count_Insignia() || (unsigned)face > INSG_Count_Faces(insig))
		return false;
	int i;
	float a[3], b[3];

	for (i = 0; i < 3; i++)
	{
		vert_indecies[i] =	insignia.insignias[insig].faces[face].points[i].vertex_index;
		a[i] =				insignia.insignias[insig].faces[face].points[i].u_texture_coordinate ;
		b[i] =				insignia.insignias[insig].faces[face].points[i].v_texture_coordinate;
	}
		
	memcpy((char *) &u_tex_coord, (char *) a, sizeof(vector3d)); 	memcpy((char *) &v_tex_coord,  (char *) b, sizeof(vector3d));	

	return true;
}




bool POF::INSG_Del_Insignia			(int insg)
{
	if ((unsigned)insg > INSG_Count_Insignia())
		return false;
	insignia.insignias.erase(insignia.insignias.begin() + insg);
	return true;
}

bool POF::INSG_Del_Insig_Vertex		(int insig, int vert)
{
		if ((unsigned)insig > INSG_Count_Insignia() || (unsigned)vert > INSG_Count_Vertecies(insig))
		return false;
	insignia.insignias[insig].vertex_pos.erase(insignia.insignias[insig].vertex_pos.begin() + vert);
	return true;
}

bool POF::INSG_Del_Insig_Face		(int insig, int face)
{
			if ((unsigned)insig > INSG_Count_Insignia() || (unsigned)face > INSG_Count_Faces(insig))
		return false;
	insignia.insignias[insig].faces.erase(insignia.insignias[insig].faces.begin() + face);
	return true;
}


bool POF::INSG_Edit_Insignia			(int insig, int lod, vector3d offset)
{
	if ((unsigned)insig > INSG_Count_Insignia())
		return false;
	insignia.insignias[insig].detail_level = lod;
	insignia.insignias[insig].offset = offset;

	return true;
}

bool POF::INSG_Edit_Insig_Vertex		(int insig, int vert, vector3d vertex)
{
	if ((unsigned)insig > INSG_Count_Insignia() || (unsigned)vert > INSG_Count_Vertecies(insig))
		return false;

	insignia.insignias[insig].vertex_pos[vert] = vertex;
	return true;
}


bool POF::INSG_Edit_Insig_Face		(int insig, int face, const int vert_indecies[], const vector3d u_tex_coord, const vector3d v_tex_coord)
{
	if ((unsigned)insig > INSG_Count_Insignia() || (unsigned)face > INSG_Count_Faces(insig))
		return false;

	float a[3], b[3];
	int i;
			memcpy((char *) a, (char *) &u_tex_coord, sizeof(vector3d)); 	memcpy((char *) b, (char *) &v_tex_coord, sizeof(vector3d));	

	for (i = 0; i < 3; i++)
	{
		insignia.insignias[insig].faces[face].points[i].vertex_index = vert_indecies[i];
		insignia.insignias[insig].faces[face].points[i].u_texture_coordinate = a[i];
		insignia.insignias[insig].faces[face].points[i].v_texture_coordinate = b[i];
	}

	return true;
}


void POF::PATH_Add_Path				(std::string name, std::string parent)
{
	a_path newpath;
	newpath.name = APStoString(name);
	newpath.parent = APStoString(parent);
	paths.paths.push_back(newpath);
}

bool POF::PATH_Add_Vert				(int path, vector3d point, float rad)
{
	if ((unsigned)path > PATH_Count_Paths())
		return false;
	path_vert newvert;
	newvert.pos = point;
	newvert.radius = rad;
	paths.paths[path].verts.push_back(newvert);
	return true;
}

bool POF::PATH_Add_Turret			(int path, int vert, int sobj_number)
{
	if (path < 0 || vert < 0 || (unsigned)path > PATH_Count_Paths() || (unsigned)path > PATH_Count_Verts(path))
		return false;
	paths.paths[path].verts[vert].sobj_number.push_back(sobj_number);
	return true;
}


bool POF::PATH_Del_Path				(int path)
{
	if ((unsigned)path > PATH_Count_Paths())
		return false;
	paths.paths.erase(paths.paths.begin() + path);
	return true;
}

bool POF::PATH_Del_Vert				(int path, int vert)
{
	if ((unsigned)path > PATH_Count_Paths() || (unsigned)vert > PATH_Count_Verts(path))
		return false;
	paths.paths[path].verts.erase(paths.paths[path].verts.begin() + vert);
	return true;
}

bool POF::PATH_Del_Turret			(int path, int vert, int turret)
{
	if ((unsigned)path > PATH_Count_Paths() || (unsigned)vert > PATH_Count_Verts(path) || (unsigned)turret > PATH_Count_Turrets(path, vert))
		return false;
	paths.paths[path].verts[vert].sobj_number.erase(paths.paths[path].verts[vert].sobj_number.begin() + turret);
	return true;
}


unsigned int POF::PATH_Count_Paths			()
{
	return paths.paths.size();
}

unsigned int POF::PATH_Count_Verts			(int path)
{
	if ((unsigned)path > PATH_Count_Paths())
		return -1;
	return paths.paths[path].verts.size();
}

unsigned int POF::PATH_Count_Turrets		(int path, int vert)
{
	if ((unsigned)path > PATH_Count_Paths() || (unsigned)vert > PATH_Count_Verts(path))
		return -1;

	return paths.paths[path].verts[vert].sobj_number.size();
}


bool POF::PATH_Get_Path				(int path, std::string &name, std::string &parents)
{
	if ((unsigned)path > PATH_Count_Paths())
		return false;

	name = StringToAPS(paths.paths[path].name);
	parents = StringToAPS(paths.paths[path].parent);
	return true;
}

bool POF::PATH_Get_Vert				(int path, int vert, vector3d &point, float &rad)
{
	if ((unsigned)path > PATH_Count_Paths() || (unsigned)vert > PATH_Count_Verts(path))
		return false;
	
	point = paths.paths[path].verts[vert].pos;
	rad = paths.paths[path].verts[vert].radius;

	return true;
}

bool POF::PATH_Get_Turret			(int path, int vert, int turret, int &sobj_number)
{
		if (path < 0 || vert < 0 || turret < 0 || 
		(unsigned)path > PATH_Count_Paths() || 
		(unsigned)vert > PATH_Count_Verts(path) || 
		(unsigned)turret > PATH_Count_Turrets(path, vert))
		return false;

	sobj_number = paths.paths[path].verts[vert].sobj_number[turret];
	return true;
}


bool POF::PATH_Edit_Path				(int path, std::string name, std::string parent)
{
	if ((unsigned)path > PATH_Count_Paths())
		return false;

	paths.paths[path].name = APStoString(name);
	paths.paths[path].parent = APStoString(parent);
	return true;
}

bool POF::PATH_Edit_Vert				(int path, int vert, vector3d point, float rad)
{
	if ((unsigned)path > PATH_Count_Paths() || (unsigned)vert > PATH_Count_Verts(path))
		return false;
	
	paths.paths[path].verts[vert].pos = point;
	paths.paths[path].verts[vert].radius = rad;

	return true;
}

bool POF::PATH_Edit_Turret			(int path, int vert, int turret, int sobj_number)
{
		if ((unsigned)path > PATH_Count_Paths() || (unsigned)vert > PATH_Count_Verts(path) || 
		(unsigned)turret > PATH_Count_Turrets(path, vert))
		return false;

	paths.paths[path].verts[vert].sobj_number[turret] = sobj_number;
	return true;
}



void POF::GLOW_Add_LightGroup		(int disp_time, int on_time, int off_time, int obj_parent, int LOD, int type, std::string properties)
{
	HullLights n;

	n.disp_time = disp_time;
	n.obj_parent = obj_parent;
	n.off_time = off_time;
	n.on_time = on_time;
	n.LOD = LOD;
	n.type = type;
	n.properties = APStoString(properties);
	hull_lights.lights.push_back(n);
}


bool POF::GLOW_Add_GlowPoint		(int group, float radius, vector3d pos, vector3d norm)
{
	if (group < 0 || (unsigned)group >= GLOW_Count_LightGroups())
		return false;

	HullLightPoint n;
	n.norm = norm;
	n.radius = radius;
	n.point = pos;
	hull_lights.lights[group].lights.push_back(n);
	return true;
}


unsigned int POF::GLOW_Count_Glows			(int group)
{
	if (group < 0 || (unsigned)group > GLOW_Count_LightGroups())
		return -1;
	return hull_lights.lights[group].lights.size();
}



bool POF::GLOW_Edit_GlowPoint		(int group, int gp, float radius, vector3d pos, vector3d norm)
{
	if (group < 0 || (unsigned)group >= GLOW_Count_LightGroups())
		return false;
	if (gp < 0 || (unsigned)gp > GLOW_Count_Glows(group))
		return false;

	hull_lights.lights[group].lights[gp].radius = radius;
	hull_lights.lights[group].lights[gp].norm = norm;
	hull_lights.lights[group].lights[gp].point = pos;

	return true;
}

bool POF::GLOW_Edit_Group			(int group, int disp_time, int on_time, int off_time, int obj_parent, int LOD, int type, std::string properties)
{
		if (group < 0 || (unsigned)group >= GLOW_Count_LightGroups())
			return false;
		hull_lights.lights[group].disp_time = disp_time;
		hull_lights.lights[group].on_time = on_time;
		hull_lights.lights[group].off_time = off_time;
		hull_lights.lights[group].obj_parent = obj_parent;
		hull_lights.lights[group].LOD = LOD;
		hull_lights.lights[group].type = type;
		
		hull_lights.lights[group].properties = APStoString(properties);
	
		return true;
}

bool POF::GLOW_Del_Group			(int group)
{
	if ((unsigned)group > GLOW_Count_LightGroups() || group < 0)
		return false;
	hull_lights.lights.erase(hull_lights.lights.begin() + group);
	return true;
}

bool POF::GLOW_Del_GlowPoint		(int group, int glowpoint)
{
	if (group < 0 || (unsigned)group >= GLOW_Count_LightGroups())
		return false;
	if (glowpoint < 0 || (unsigned)glowpoint > GLOW_Count_Glows(group))
		return false;
	hull_lights.lights[group].lights.erase(hull_lights.lights[group].lights.begin() + group);
	return true;
}

bool POF::GLOW_Get_GlowPoint		(int group, int gp, float &radius, vector3d &pos, vector3d &norm)
{
	if (group < 0 || (unsigned)group >= GLOW_Count_LightGroups())
		return false;
	if (gp < 0 || (unsigned)gp > GLOW_Count_Glows(group))
		return false;
		radius = hull_lights.lights[group].lights[gp].radius;
	pos	= hull_lights.lights[group].lights[gp].point;
	norm = hull_lights.lights[group].lights[gp].norm;
	return true;
}

bool POF::GLOW_Get_Group		(int group, int &disp_time, int &on_time, int &off_time, int &obj_parent, int &LOD, int &type, std::string &properties)
{
	if (group < 0 || (unsigned)group >= GLOW_Count_LightGroups())
		return false;
		disp_time = hull_lights.lights[group].disp_time;
	on_time = hull_lights.lights[group].on_time;
	off_time = hull_lights.lights[group].off_time;
	obj_parent = hull_lights.lights[group].obj_parent;
	LOD = hull_lights.lights[group].LOD;
	type = hull_lights.lights[group].type;
	properties = StringToAPS(hull_lights.lights[group].properties);
	return true;
}



void POF::PINF_Set					(std::string pof_info)
{
	pofinfo.strings.resize(pof_info.length()+1);
	memcpy(&pofinfo.strings.front(), pof_info.c_str(), pof_info.length());
	pofinfo.strings[pof_info.length()] = '\0';
}

void POF::PINF_Set					(char *str, int sz)
{
	pofinfo.strings.resize(sz+1);
	memcpy(&pofinfo.strings.front(), str, sz);
	pofinfo.strings[sz] = '\0';
}

bool POF::PINF_Del()
{
	pofinfo.strings.clear();
	return true;
}

std::vector<std::string> POF::PINF_Get				()
{
	std::vector<std::string> strings;
	if (pofinfo.strings.empty())
		return strings;

	for (size_t pos = 0; pos < pofinfo.strings.size() && pofinfo.strings[pos] != '\0'; pos += strlen(&pofinfo.strings.front()+pos)+1)
	{
			strings.resize(strings.size()+1);
			strings[strings.size()-1] = (char*)(&pofinfo.strings.front()+pos);
	}

	return strings;
}



```

## POFHandler.h

```cpp


#include <iostream>


#include <fstream>
#include "POFDataStructs.h"
#include <string>

#if !defined(_POF_HANDLER_H_)
#define _POF_HANDLER_H_




class POF {
	private:
		TXTR textures;
		HDR2 header;

		std::vector<OBJ2> objects;

		SPCL specials;
		GPNT_MPNT gunpoints;
		GPNT_MPNT missilepoints;
		TGUN_TMIS turretguns;
		TGUN_TMIS turretmissiles;
		DOCK docking;
		FUEL thrusters;
		SHLD shields;
		EYE eyes;
		ACEN autocentering;
		INSG insignia;
		PATH paths;
		GLOW hull_lights; 		SLDC shield_collision;
		PINF pofinfo;



						void Parse_Memory_PNT(int mode, char *buffer);

		void Parse_Memory_T(int mode, char *buffer);

		void Parse_Memory_TXTR(char *buffer);
		void Parse_Memory_HDR2(char *buffer);
		void Parse_Memory_OBJ2(char *buffer);
		void Parse_Memory_SPCL(char *buffer);

		void Parse_Memory_GPNT(char *buffer)
			{ Parse_Memory_PNT(0, buffer); }

		void Parse_Memory_MPNT(char *buffer)
			{ Parse_Memory_PNT(1, buffer); }


		void Parse_Memory_TGUN(char *buffer)
			{ Parse_Memory_T(0, buffer); }

		void Parse_Memory_TMIS(char *buffer)
			{  Parse_Memory_T(1, buffer); }

		void Parse_Memory_DOCK(char *buffer);
		void Parse_Memory_FUEL(char *buffer);
		void Parse_Memory_GLOW(char *buffer);
		void Parse_Memory_SHLD(char *buffer);
		void Parse_Memory_EYE(char *buffer);
		void Parse_Memory_ACEN(char *buffer);
		void Parse_Memory_INSG(char *buffer);
		void Parse_Memory_PATH(char *buffer);
		void Parse_Memory_SLDC(char *buffer);
		void Parse_Memory_PINF (char *buffer, int size);



						void PNT_AddSlot				(int mode);
		unsigned int PNT_SlotCount		(int mode);
		unsigned int PNT_PointCount		(int mode, int slot);
		bool PNT_DelSlot				(int mode, int slot_num);
		bool PNT_DelPoint				(int mode, int slot, int point);
		bool PNT_AddPoint				(int mode, int slot, vector3d point, vector3d norm);
		bool PNT_EditPoint				(int mode, int slot, int point_num, vector3d point, vector3d norm);
		bool PNT_GetPoint				(int mode, int slot, int point_num, vector3d &point, vector3d &norm);


						void T_Add_Bank					(int mode, int sobj_parent, int sobj_par_phys, vector3d normal);
		bool T_Add_FirePoint			(int mode, int bank, vector3d pos);
		bool T_Edit_Bank				(int mode, int bank, int sobj_parent, int sobj_par_phys, vector3d normal);
		bool T_Edit_FirePoint			(int mode, int bank, int point, vector3d pos);
		bool T_Del_FirePoint			(int mode, int bank, int point);
		bool T_Del_Bank					(int mode, int bank);
		unsigned int T_Count_Banks		(int mode);
		unsigned int T_Count_Points		(int mode, int bank);
		bool T_Get_Bank					(int mode, int bank, int &sobj_parent, int &sobj_par_phys, vector3d &normal);
		bool T_Get_FirePoint			(int mode, int bank, int point, vector3d &pos);

		void ClearAllData();

		GPNT_MPNT* PNT_Alias(int mode); 		TGUN_TMIS* T_Alias(int mode); 
	public:
		int version; 												void Reset() 		{
			version = 2117;
			ClearAllData();
		}

				int LoadPOF(std::ifstream &infile);  		bool SavePOF(std::ofstream &outfile); 
				void StatsToFile(std::ofstream &outfile);

				POF(std::ifstream &infile) 		{
			version = 2117;
			ClearAllData();
			LoadPOF(infile);
		}

		POF()
			{ ClearAllData(); version = 2117; }
						virtual ~POF() 			{}

				int SLDC_GetSize() { return shield_collision.tree_data.size(); }
		const std::vector<char>& SLDC_GetTree() { return shield_collision.tree_data; }
		void SLDC_SetTree(const std::vector<char>& sldc_tree); 		void SLDC_SetTree(std::vector<char>&& sldc_tree); 
				int TXTR_AddTexture(std::string texname);
		bool TXTR_DelTexture(int texture);
		int TXTR_FindTexture(std::string texname);
		bool TXTR_Edit_Texture(int texture, std::string textname);
		std::string TXTR_GetTextures(int texture);

		unsigned int TXTR_Count_Textures()
			{ return textures.tex_filename.size(); }


				void HDR2_Set_MaxRadius				(float maximum_radius)
			{ header.max_radius = maximum_radius; }

		void HDR2_Set_ObjectFlags			(int object_flags)
			{ header.obj_flags = object_flags; }

		void HDR2_Set_SOBJCount				(int count)
			{ header.num_subobjects = count;	}

		void HDR2_Set_MinBound				(vector3d min)
			{ header.min_bounding = min; }

		void HDR2_Set_MaxBound				(vector3d max)
			{ header.max_bounding = max; }

		void HDR2_Set_Details				(int num, std::vector<int> SOBJ_nums);
		void HDR2_Set_Debris				(int num, std::vector<int> SOBJ_nums);

		void HDR2_Set_Mass					(float mass)
			{ header.mass = mass; }

		void HDR2_Set_MassCenter			(vector3d center)
			{ header.mass_center = center; }


		void HDR2_Set_MomentInertia			(float inertia[3][3]);
		void HDR2_Set_CrossSections			(int num, std::vector<cross_section> sections);
		void HDR2_Set_Lights				(int num, const std::vector<muzzle_light> &li);

		float HDR2_Get_MaxRadius			()
			{ return header.max_radius; }

		int HDR2_Get_ObjectFlags			()
			{ return header.obj_flags; }

		unsigned int HDR2_Get_SOBJCount		()
			{ return header.num_subobjects; }

		vector3d HDR2_Get_MinBound			()
			{ return header.min_bounding; }

		vector3d HDR2_Get_MaxBound			()
			{ return header.max_bounding; }

		void HDR2_Get_Details				(int &num, std::vector<int> &SOBJ_nums);
		void HDR2_Get_Debris				(int &num, std::vector<int> &SOBJ_nums);

		float HDR2_Get_Mass					()
			{ return header.mass; }

		vector3d HDR2_Get_MassCenter			()
			{ return header.mass_center; }

		void HDR2_Get_MomentInertia			(float inertia[3][3]);
		void HDR2_Get_CrossSections			(int &num, std::vector<cross_section> &sections);
		void HDR2_Get_Lights				(int &num, std::vector<muzzle_light> &li);



				int  OBJ2_Add						(OBJ2 &obj);
		int  OBJ2_Add_SOBJ					();
		bool OBJ2_Del_SOBJ					(int SOBJNum);

		bool OBJ2_Set_SOBJNum				(int SOBJNum, int num);
		bool OBJ2_Set_Radius				(int SOBJNum, float rad);
		bool OBJ2_Set_Parent				(int SOBJNum, int parent);
		bool OBJ2_Set_Offset				(int SOBJNum, vector3d offset);
		bool OBJ2_Set_GeoCenter				(int SOBJNum, vector3d GeoCent);
		bool OBJ2_Set_BoundingMin			(int SOBJNum, vector3d min);
		bool OBJ2_Set_BoundingMax			(int SOBJNum, vector3d max);
		bool OBJ2_Set_Name					(int SOBJNum, std::string name);
		bool OBJ2_Set_Props					(int SOBJNum, std::string properties);
		bool OBJ2_Set_MoveType				(int SOBJNum, int type);
		bool OBJ2_Set_MoveAxis				(int SOBJNum, int axis);


		unsigned int OBJ2_BSP_Datasize(int SOBJNum);
		unsigned int OBJ2_Count();

		bool OBJ2_Get_SOBJNum				(int SOBJNum, int &num);
		bool OBJ2_Get_Radius				(int SOBJNum, float &rad);
		bool OBJ2_Get_Parent				(int SOBJNum, int &parent);
		bool OBJ2_Get_Offset				(int SOBJNum, vector3d &offset);
		bool OBJ2_Get_GeoCenter				(int SOBJNum, vector3d &GeoCent);
		bool OBJ2_Get_BoundingMin			(int SOBJNum, vector3d &min);
		bool OBJ2_Get_BoundingMax			(int SOBJNum, vector3d &max);
		bool OBJ2_Get_Name					(int SOBJNum, std::string &name);
		bool OBJ2_Get_Props					(int SOBJNum, std::string &properties);
		bool OBJ2_Get_MoveType				(int SOBJNum, int &type);
		bool OBJ2_Get_MoveAxis				(int SOBJNum, int &axis);
		bool OBJ2_Get_BSPData				(int SOBJNum, std::vector<char> &bsp_data);
		bool OBJ2_Get_BSPDataPtr			(int SOBJNum, int &size, char* &bsp_data);
				void SPCL_AddSpecial				(std::string Name, std::string Properties, vector3d point, float radius);
		bool SPCL_DelSpecial				(int num);
		unsigned int SPCL_Count				();
		bool SPCL_Get_Special				(int num, std::string &Name, std::string &Properties, vector3d &point, float &radius);
		bool SPCL_Edit_Special				(int num, std::string Name, std::string Properties, vector3d point, float radius);



												void GPNT_AddSlot()
			{ PNT_AddSlot(0); }

		unsigned int GPNT_SlotCount()
			{ return PNT_SlotCount(0); }

		unsigned int GPNT_PointCount(int slot)
			{ return PNT_PointCount(0, slot); }

		bool GPNT_DelSlot(int slot)
			{ return PNT_DelSlot(0, slot); }

		bool GPNT_DelPoint(int slot, int point)
			{ return PNT_DelPoint(0, slot, point); }

		bool GPNT_AddPoint(int slot, vector3d point, vector3d norm)
			{ return PNT_AddPoint(0, slot, point, norm); }

		bool GPNT_EditPoint(int slot, int point_num, vector3d point, vector3d norm)
			{ return PNT_EditPoint(0, slot, point_num, point, norm); }

		bool GPNT_GetPoint(int slot, int point_num, vector3d &point, vector3d &norm)
			{ return PNT_GetPoint(0, slot, point_num, point, norm); }

				void MPNT_AddSlot()
			{ PNT_AddSlot(1); }

		unsigned int MPNT_SlotCount()
			{ return PNT_SlotCount(1); }

		unsigned int MPNT_PointCount(int slot)
			{ return PNT_PointCount(1, slot); }

		bool MPNT_DelSlot(int slot)
			{ return PNT_DelSlot(1, slot); }

		bool MPNT_DelPoint(int slot, int point)
			{ return PNT_DelPoint(1, slot, point); }

		bool MPNT_AddPoint(int slot, vector3d point, vector3d norm)
			{ return PNT_AddPoint(1, slot, point, norm); }

		bool MPNT_EditPoint(int slot, int point_num, vector3d point, vector3d norm)
			{ return PNT_EditPoint(1, slot, point_num, point, norm); }

		bool MPNT_GetPoint(int slot, int point_num, vector3d &point, vector3d &norm)
			{ return PNT_GetPoint(1, slot, point_num, point, norm); }

										
		void TGUN_Add_Bank(int sobj_parent, int sobj_par_phys, vector3d normal)
			{ T_Add_Bank(0, sobj_parent, sobj_par_phys, normal); }

		bool TGUN_Add_FirePoint(int bank, vector3d pos)
			{ return T_Add_FirePoint(0, bank, pos); }

		bool TGUN_Edit_Bank(int bank, int sobj_parent, int sobj_par_phys, vector3d normal)
			{ return T_Edit_Bank(0, bank, sobj_parent, sobj_par_phys, normal); }

		bool TGUN_Edit_FirePoint(int bank, int point, vector3d pos)
			{ return T_Edit_FirePoint(0, bank, point, pos); }

		bool TGUN_Del_FirePoint(int bank, int point)
			{ return T_Del_FirePoint(0, bank, point); }

		bool TGUN_Del_Bank(int bank)
			{ return T_Del_Bank(0, bank); }

		unsigned int TGUN_Count_Banks()
			{ return T_Count_Banks(0); }

		unsigned int TGUN_Count_Points(int bank)
			{ return T_Count_Points(0, bank); }

		bool TGUN_Get_Bank(int bank, int &sobj_parent, int &sobj_par_phys, vector3d &normal)
			{ return T_Get_Bank(0, bank, sobj_parent, sobj_par_phys, normal); }

		bool TGUN_Get_FirePoint(int bank, int point, vector3d &pos)
			{ return T_Get_FirePoint(0, bank, point, pos); }

		

		void TMIS_Add_Bank(int sobj_parent, int sobj_par_phys, vector3d normal)
			{ T_Add_Bank(1, sobj_parent, sobj_par_phys, normal); }

		bool TMIS_Add_FirePoint(int bank, vector3d pos)
			{ return T_Add_FirePoint(1, bank, pos); }

		bool TMIS_Edit_Bank(int bank, int sobj_parent, int sobj_par_phys, vector3d normal)
			{ return T_Edit_Bank(1, bank, sobj_parent, sobj_par_phys, normal); }

		bool TMIS_Edit_FirePoint(int bank, int point, vector3d pos)
			{ return T_Edit_FirePoint(1, bank, point, pos); }

		bool TMIS_Del_FirePoint(int bank, int point)
			{ return T_Del_FirePoint(1, bank, point); }

		bool TMIS_Del_Bank(int bank)
			{ return T_Del_Bank(1, bank); }

		unsigned int TMIS_Count_Banks()
			{ return T_Count_Banks(1); }

		unsigned int TMIS_Count_Points(int bank)
			{ return T_Count_Points(1, bank); }

		bool TMIS_Get_Bank(int bank, int &sobj_parent, int &sobj_par_phys, vector3d &normal)
			{ return T_Get_Bank(1, bank, sobj_parent, sobj_par_phys, normal); }

		bool TMIS_Get_FirePoint(int bank, int point, vector3d &pos)
			{ return T_Get_FirePoint(1, bank, point, pos); }


				void DOCK_Add_Dock				(std::string properties);
		bool DOCK_Add_SplinePath		(int dock, int path);
		bool DOCK_Add_Point				(int dock, vector3d point, vector3d norm);

		unsigned int DOCK_Count_Docks			();
		unsigned int DOCK_Count_SplinePaths		(int dock);
		unsigned int DOCK_Count_Points			(int dock);

		bool DOCK_Get_SplinePath		(int dock, int spline_path_num, int &path);
		bool DOCK_Get_Point				(int dock, int point, vector3d &pnt, vector3d &norm);
		bool DOCK_Get_DockProps			(int dock, std::string &properties);

		bool DOCK_Edit_SplinePath		(int dock, int spline_path_num, int path);
		bool DOCK_Edit_Point			(int dock, int point, vector3d pnt, vector3d norm);
		bool DOCK_Edit_DockProps		(int dock, std::string properties);

		bool DOCK_Del_Dock				(int dock);
		bool DOCK_Del_SplinePath		(int dock, int spline_path_num);
		bool DOCK_Del_Point				(int dock, int point);

		
		void FUEL_Add_Thruster			(std::string properties);
		bool FUEL_Add_GlowPoint			(int bank, float radius, vector3d pos, vector3d norm);

		unsigned int FUEL_Count_Thrusters		();
		unsigned int FUEL_Count_Glows			(int thruster);

		bool FUEL_Edit_GlowPoint		(int thruster, int gp, float radius, vector3d pos, vector3d norm);
		bool FUEL_Edit_ThrusterProps	(int thruster, std::string properties);

		bool FUEL_Del_Thruster			(int thrust);
		bool FUEL_Del_GlowPoint			(int thruster, int glowpoint);

		bool FUEL_Get_GlowPoint			(int thruster, int gp, float &radius, vector3d &pos, vector3d &norm);
		bool FUEL_Get_ThrusterProps		(int thruster, std::string &properties);

		
		void GLOW_Add_LightGroup		(int disp_time, int on_time, int off_time, int obj_parent, int LOD, int type, std::string properties = "$glow_texture=thrusterglow01");
		bool GLOW_Add_GlowPoint			(int group, float radius, vector3d pos, vector3d norm);

		unsigned int GLOW_Count_LightGroups		()
			{	return hull_lights.lights.size(); }

		unsigned int GLOW_Count_Glows			(int group);

		bool GLOW_Edit_GlowPoint		(int group, int gp, float radius, vector3d pos, vector3d norm);
		bool GLOW_Edit_Group			(int group, int disp_time, int on_time, int off_time, int obj_parent, int LOD, int type, std::string properties);

		bool GLOW_Del_Group				(int group);
		bool GLOW_Del_GlowPoint			(int group, int glowpoint);

		bool GLOW_Get_GlowPoint			(int group, int gp, float &radius, vector3d &pos, vector3d &norm);
		bool GLOW_Get_Group				(int group, int &disp_time, int &on_time, int &off_time, int &obj_parent, int &LOD, int &type, std::string &properties);

		
		void SHLD_Add_Vertex			(vector3d vert);
		void SHLD_Add_Face				(vector3d normal, const int fcs[3], const int nbs[3]);
										
		unsigned int SHLD_Count_Vertices			();
		unsigned int SHLD_Count_Faces			();

		bool SHLD_Get_Face				(int face, vector3d &normal, int fcs[3], int nbs[3]);
		bool SHLD_Get_Vertex			(int vertex, vector3d &vert);

		bool SHLD_Edit_Vertex			(int vertex, vector3d &vert);
		bool SHLD_Edit_Face				(int face, vector3d normal, const int fcs[3], const int nbs[3]);

		bool SHLD_Del_Vertex			(int vertex);
		bool SHLD_Del_Face				(int face);

				void EYE_Add_Eye				(int sobj_num, vector3d offset, vector3d normal);
		bool EYE_Del_Eye				(int eye);
		unsigned int  EYE_Count_Eyes				();
		bool EYE_Get_Eye				(int eye, int &sobj_num, vector3d &offset, vector3d &normal);
		bool EYE_Edit_Eye				(int eye, int sobj_num, vector3d offset, vector3d normal);

				void ACEN_Set_acen				(vector3d point);
		bool ACEN_Del_acen				();
		vector3d ACEN_Get_acen			();
		bool ACEN_IsSet					();


		
		void INSG_Add_insignia			(int lod, vector3d offset);
		bool INSG_Add_Insig_Vertex		(int insig, vector3d vertex);
		bool INSG_Add_Insig_Face		(int insig, const int vert_indecies[3], const vector3d u_tex_coord, const vector3d v_tex_coord);
		bool INSG_Add_Insig_Face		(int insig, insg_face &InsgFace);

		unsigned int  INSG_Count_Insignia		();
		unsigned int  INSG_Count_Vertecies		(int insig);
		unsigned int  INSG_Count_Faces			(int insig);

		bool INSG_Get_Insignia			(int insig, int &lod, vector3d &offset);
		bool INSG_Get_Insig_Vertex		(int insig, int vert, vector3d &vertex);
		bool INSG_Get_Insig_Face		(int insig, int face, int vert_indecies[3], vector3d &u_tex_coord, vector3d &v_tex_coord);
		int  INST_Find_Vert				(int insig, vector3d vertex);

		bool INSG_Del_Insignia			(int insg);
		bool INSG_Del_Insig_Vertex		(int insig, int vert);
		bool INSG_Del_Insig_Face		(int insig, int face);

		bool INSG_Edit_Insignia			(int insig, int lod, vector3d offset);
		bool INSG_Edit_Insig_Vertex		(int insig, int vert, vector3d vertex);
		bool INSG_Edit_Insig_Face		(int insig, int face, const int vert_indecies[3], const vector3d u_tex_coord, const vector3d v_tex_coord);


				void PATH_Add_Path				(std::string name, std::string parent);
		bool PATH_Add_Vert				(int path, vector3d point, float rad);
		bool PATH_Add_Turret			(int path, int vert, int sobj_number);

		unsigned int  PATH_Count_Paths			();
		unsigned int  PATH_Count_Verts			(int path);
		unsigned int  PATH_Count_Turrets			(int path, int vert);

		bool PATH_Get_Path				(int path, std::string &name, std::string &parents);
		bool PATH_Get_Vert				(int path, int vert, vector3d &point, float &rad);
		bool PATH_Get_Turret			(int path, int vert, int turret, int &sobj_number);

		bool PATH_Del_Path				(int path);
		bool PATH_Del_Vert				(int path, int vert);
		bool PATH_Del_Turret			(int path, int vert, int turret);

		bool PATH_Edit_Path				(int path, std::string name, std::string parent);
		bool PATH_Edit_Vert				(int path, int vert, vector3d point, float rad);
		bool PATH_Edit_Turret			(int path, int vert, int turret, int sobj_number);

				void PINF_Set					(std::string pof_info);
		void PINF_Set					(char *str, int sz);
		bool PINF_Del					();
		std::vector<std::string> PINF_Get();

};


#define APStoString(x) x
#define StringToAPS(x) x

#endif 
```
